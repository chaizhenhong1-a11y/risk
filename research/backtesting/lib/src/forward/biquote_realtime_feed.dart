import 'dart:async';

import 'biquote_bootstrap.dart';
import 'biquote_closed_bar_store.dart';
import 'biquote_feed_guard.dart';
import 'biquote_market_data.dart';
import 'biquote_rest_client.dart';
import 'biquote_signalr_client.dart';

enum BiQuoteRuntimeState { connecting, live, marketClosed, offline, stopped }

/// Owns the authoritative market-data runtime state.
///
/// MARKET_CLOSED is only produced by an explicit BiQuote "no fresh tick"
/// response. Transport/provider failures are OFFLINE, never MARKET_CLOSED.
final class BiQuoteRealtimeFeed {
  BiQuoteRealtimeFeed({
    BiQuoteRestClient? restClient,
    BiQuoteSignalRClient? streamClient,
    BiQuoteClosedBarStore? store,
    this.guard = const BiQuoteTickGuard(),
    this.marketProbeInterval = const Duration(seconds: 30),
  }) : restClient = restClient ?? BiQuoteRestClient(),
       streamClient = streamClient ?? BiQuoteSignalRClient(),
       store = store ?? BiQuoteClosedBarStore();

  final BiQuoteRestClient restClient;
  final BiQuoteSignalRClient streamClient;
  final BiQuoteClosedBarStore store;
  final BiQuoteTickGuard guard;
  final Duration marketProbeInterval;

  final StreamController<BiQuoteRuntimeState> _runtimeStates =
      StreamController<BiQuoteRuntimeState>.broadcast();

  StreamSubscription<BiQuoteStreamState>? _streamStateSubscription;
  Timer? _marketProbeTimer;
  BiQuoteRuntimeState _runtimeState = BiQuoteRuntimeState.connecting;
  bool _probeInFlight = false;
  bool _disposed = false;
  String _symbol = 'XAUUSD';
  int _warmupPerTimeframe = 500;

  Stream<BiQuoteTick> get ticks => streamClient.ticks;
  Stream<BiQuoteStreamState> get states => streamClient.states;
  Stream<BiQuoteSignalRDiagnostic> get diagnostics => streamClient.diagnostics;
  Stream<BiQuoteRuntimeState> get runtimeStates => _runtimeStates.stream;
  BiQuoteRuntimeState get runtimeState => _runtimeState;

  Future<BiQuoteBootstrapReport> start({
    String symbol = 'XAUUSD',
    int warmupPerTimeframe = 500,
  }) async {
    _symbol = symbol;
    _warmupPerTimeframe = warmupPerTimeframe;
    _disposed = false;
    _setRuntimeState(BiQuoteRuntimeState.connecting);

    _streamStateSubscription ??= streamClient.states.listen(_onStreamState);

    final report = await _probeAndRecover(initial: true);
    _marketProbeTimer?.cancel();
    _marketProbeTimer = Timer.periodic(
      marketProbeInterval,
      (_) => unawaited(_probeAndRecover()),
    );
    return report;
  }

  Future<BiQuoteBootstrapReport> recover({
    String symbol = 'XAUUSD',
    int barsPerTimeframe = 100,
  }) async {
    _symbol = symbol;
    _warmupPerTimeframe = barsPerTimeframe;
    return _probeAndRecover();
  }

  Future<BiQuoteBootstrapReport> _probeAndRecover({
    bool initial = false,
  }) async {
    if (_disposed || _probeInFlight) return _emptyReport;
    _probeInFlight = true;
    try {
      final symbol = _symbol;
      final tick = await restClient.latestTickOrNull(symbol);

      if (tick == null) {
        streamClient.setRestHealthAllowed(false);
        _setRuntimeState(BiQuoteRuntimeState.marketClosed);
        return await _bootstrapOrEmpty();
      }

      final health = guard.evaluate(tick);
      final restHealthy = health == BiQuoteTickHealth.healthy;
      streamClient.setRestHealthAllowed(restHealthy);
      if (!restHealthy) {
        _setRuntimeState(BiQuoteRuntimeState.offline);
        return await _bootstrapOrEmpty();
      }

      // Refresh canonical CLOSED bars before opening/re-opening the live stream.
      final report = await _bootstrapOrEmpty();
      if (_disposed) return report;

      if (restHealthy) {
        if (streamClient.state != BiQuoteStreamState.connected &&
            streamClient.state != BiQuoteStreamState.connecting &&
            streamClient.state != BiQuoteStreamState.reconnecting) {
          _setRuntimeState(BiQuoteRuntimeState.connecting);
          unawaited(streamClient.start());
        } else if (streamClient.state == BiQuoteStreamState.connected) {
          _setRuntimeState(BiQuoteRuntimeState.live);
        }
      }
      return report;
    } catch (_) {
      streamClient.setRestHealthAllowed(false);
      _setRuntimeState(BiQuoteRuntimeState.offline);
      return _emptyReport;
    } finally {
      _probeInFlight = false;
    }
  }

  Future<BiQuoteBootstrapReport> _bootstrapOrEmpty() async {
    try {
      return await const BiQuoteBootstrap().load(
        client: restClient,
        store: store,
        symbol: _symbol,
        limitPerTimeframe: _warmupPerTimeframe,
      );
    } catch (_) {
      // Runtime state remains authoritative. A failed REST bootstrap must not
      // crash the process or manufacture a live state.
      return _emptyReport;
    }
  }

  void _onStreamState(BiQuoteStreamState state) {
    if (_disposed) return;
    switch (state) {
      case BiQuoteStreamState.connected:
        _setRuntimeState(BiQuoteRuntimeState.live);
      case BiQuoteStreamState.connecting:
      case BiQuoteStreamState.reconnecting:
        if (_runtimeState != BiQuoteRuntimeState.marketClosed) {
          _setRuntimeState(BiQuoteRuntimeState.connecting);
        }
      case BiQuoteStreamState.disconnected:
        if (_runtimeState != BiQuoteRuntimeState.marketClosed) {
          _setRuntimeState(BiQuoteRuntimeState.offline);
        }
      case BiQuoteStreamState.stopped:
        if (_disposed) {
          _setRuntimeState(BiQuoteRuntimeState.stopped);
        }
    }
  }

  void _setRuntimeState(BiQuoteRuntimeState value) {
    if (_runtimeState == value) return;
    _runtimeState = value;
    if (!_runtimeStates.isClosed) _runtimeStates.add(value);
  }

  static const BiQuoteBootstrapReport _emptyReport = BiQuoteBootstrapReport(
    receivedClosedBars: 0,
    ignoredOpenBars: 0,
    addedClosedBars: 0,
    duplicates: 0,
  );

  Future<void> dispose() async {
    _disposed = true;
    _marketProbeTimer?.cancel();
    _marketProbeTimer = null;
    await _streamStateSubscription?.cancel();
    _streamStateSubscription = null;
    await streamClient.dispose();
    restClient.close();
    _setRuntimeState(BiQuoteRuntimeState.stopped);
    await _runtimeStates.close();
  }
}
