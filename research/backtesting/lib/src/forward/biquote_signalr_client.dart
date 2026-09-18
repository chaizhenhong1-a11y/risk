import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'biquote_feed_guard.dart';
import 'biquote_market_data.dart';
import 'biquote_signalr_protocol.dart';

enum BiQuoteStreamState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  stopped,
}

final class BiQuoteSignalRDiagnostic {
  const BiQuoteSignalRDiagnostic(this.message);
  final String message;
  @override
  String toString() => message;
}

final class BiQuoteSignalRClient {
  BiQuoteSignalRClient({
    Uri? hubUri,
    this.symbols = const ['XAUUSD'],
    this.guard = const BiQuoteTickGuard(),
    this.reconnectDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ],
    HttpClient? httpClient,
  }) : hubUri = hubUri ?? Uri.parse('https://biquote.io/hubs/tick'),
       _httpClient = httpClient ?? HttpClient();

  final Uri hubUri;
  final List<String> symbols;
  final BiQuoteTickGuard guard;
  final List<Duration> reconnectDelays;
  final HttpClient _httpClient;
  final BiQuoteSignalRProtocol _protocol = const BiQuoteSignalRProtocol();

  final StreamController<BiQuoteTick> _ticks =
      StreamController<BiQuoteTick>.broadcast();
  final StreamController<BiQuoteStreamState> _states =
      StreamController<BiQuoteStreamState>.broadcast();
  final StreamController<BiQuoteSignalRDiagnostic> _diagnostics =
      StreamController<BiQuoteSignalRDiagnostic>.broadcast();

  WebSocket? _socket;
  bool _stopRequested = false;
  bool _restHealthAllowsStreaming = false;
  int _invocation = 0;
  BiQuoteStreamState _state = BiQuoteStreamState.disconnected;
  final Map<String, Completer<Map<String, dynamic>>> _pendingInvocations = {};

  Stream<BiQuoteTick> get ticks => _ticks.stream;
  Stream<BiQuoteStreamState> get states => _states.stream;
  Stream<BiQuoteSignalRDiagnostic> get diagnostics => _diagnostics.stream;
  BiQuoteStreamState get state => _state;

  void setRestHealthAllowed(bool value) {
    _restHealthAllowsStreaming = value;
    _diag('restHealthAllowsStreaming=$value');
  }

  Future<void> start() async {
    if (_state == BiQuoteStreamState.connected ||
        _state == BiQuoteStreamState.connecting) {
      return;
    }
    _stopRequested = false;
    await _connect(reconnecting: false);
  }

  Future<void> stop() async {
    _stopRequested = true;
    _setState(BiQuoteStreamState.stopped);
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close(WebSocketStatus.normalClosure, 'TradeForge stop');
    }
  }

  Future<void> dispose() async {
    await stop();
    _httpClient.close(force: true);
    await _ticks.close();
    await _states.close();
    await _diagnostics.close();
  }

  Future<void> _connect({required bool reconnecting}) async {
    _setState(
      reconnecting
          ? BiQuoteStreamState.reconnecting
          : BiQuoteStreamState.connecting,
    );

    try {
      final token = await _negotiate();
      _diag('negotiate=ok tokenLength=${token.length}');
      if (_stopRequested) return;

      final websocketUri = hubUri.replace(
        scheme: hubUri.scheme == 'https' ? 'wss' : 'ws',
        queryParameters: {'id': token},
      );
      final socket = await WebSocket.connect(websocketUri.toString());
      _socket = socket;
      _diag('websocket=connected');

      final handshakeDone = Completer<void>();
      var handshakePending = true;

      socket.listen(
        (data) {
          if (data is! String) return;
          for (final message in _protocol.decode(data)) {
            if (handshakePending) {
              handshakePending = false;
              if (message.containsKey('error')) {
                if (!handshakeDone.isCompleted) {
                  handshakeDone.completeError(
                    StateError('SignalR handshake failed: ${message['error']}'),
                  );
                }
                return;
              }
              if (!handshakeDone.isCompleted) handshakeDone.complete();
              if (message.isEmpty) continue;
            }
            _handleMessage(message);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _diag('socketError=$error');
          if (!handshakeDone.isCompleted) {
            handshakeDone.completeError(error, stackTrace);
          }
        },
        onDone: () {
          _diag('websocket=closed');
          if (!handshakeDone.isCompleted) {
            handshakeDone.completeError(
              StateError('BiQuote SignalR closed during handshake'),
            );
          }
          if (!_stopRequested) unawaited(_reconnect());
        },
        cancelOnError: false,
      );

      socket.add(_protocol.handshake());
      await handshakeDone.future.timeout(const Duration(seconds: 10));
      _diag('handshake=ok');
      if (_stopRequested) return;

      final subscribeId = '${++_invocation}';
      final completion = Completer<Map<String, dynamic>>();
      _pendingInvocations[subscribeId] = completion;
      socket.add(
        _protocol.invocation(
          invocationId: subscribeId,
          target: 'Subscribe',
          arguments: [symbols],
        ),
      );
      _diag('subscribe=sent symbols=${symbols.join(',')} id=$subscribeId');

      final response = await completion.future.timeout(
        const Duration(seconds: 10),
      );
      if (response['error'] != null) {
        throw StateError('BiQuote Subscribe failed: ${response['error']}');
      }
      _diag('subscribe=completed id=$subscribeId');
      _setState(BiQuoteStreamState.connected);
    } catch (error) {
      _diag('connectFailure=$error');
      if (!_stopRequested) await _reconnect();
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'];
    if (type == 3) {
      final id = message['invocationId'];
      if (id is String) {
        final completer = _pendingInvocations.remove(id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(message);
        }
      }
      return;
    }
    if (type == 6) return;
    if (type == 7) {
      _diag('serverClose error=${message['error'] ?? 'none'}');
      unawaited(_socket?.close());
      return;
    }
    if (type != 1 || message['target'] != 'ReceiveTick') return;

    final arguments = message['arguments'];
    if (arguments is! List || arguments.isEmpty || arguments.first is! Map) {
      _diag('ReceiveTick=invalidArguments');
      return;
    }

    try {
      final tick = BiQuoteTick.fromJson(
        Map<String, dynamic>.from(arguments.first as Map),
      );
      final health = guard.evaluateStream(
        tick,
        receivedAtUtc: DateTime.now().toUtc(),
        restHealthAllowsStreaming: _restHealthAllowsStreaming,
      );
      if (health == BiQuoteTickHealth.healthy) {
        _ticks.add(tick);
      } else {
        _diag(
          'tickFiltered symbol=${tick.symbol} health=${health.name} '
          'timestamp=${tick.timestamp.toIso8601String()}',
        );
      }
    } catch (error) {
      _diag('tickParseError=$error');
    }
  }

  Future<String> _negotiate() async {
    final negotiateUri = hubUri.replace(
      path: '${hubUri.path}/negotiate',
      queryParameters: const {'negotiateVersion': '1'},
    );
    final request = await _httpClient.postUrl(negotiateUri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.contentLength = 0;
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'BiQuote SignalR negotiate ${response.statusCode}: $body',
        uri: negotiateUri,
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Invalid SignalR negotiate response');
    }
    final json = Map<String, dynamic>.from(decoded);
    final token = json['connectionToken'] ?? json['connectionId'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('SignalR negotiate response has no token');
    }
    return token;
  }

  Future<void> _reconnect() async {
    if (_stopRequested) return;
    _setState(BiQuoteStreamState.reconnecting);
    for (final delay in reconnectDelays) {
      if (_stopRequested) return;
      await Future<void>.delayed(delay);
      if (_stopRequested) return;
      await _connect(reconnecting: true);
      if (_state == BiQuoteStreamState.connected) return;
    }
    if (!_stopRequested) _setState(BiQuoteStreamState.disconnected);
  }

  void _setState(BiQuoteStreamState value) {
    if (_state == value) return;
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  void _diag(String message) {
    if (!_diagnostics.isClosed) {
      _diagnostics.add(BiQuoteSignalRDiagnostic(message));
    }
  }
}
