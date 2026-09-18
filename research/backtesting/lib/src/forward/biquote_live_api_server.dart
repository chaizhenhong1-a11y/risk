import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'biquote_live_closed_bar_pipeline.dart';
import 'biquote_live_market_snapshot.dart';
import 'biquote_market_data.dart';
import 'biquote_realtime_feed.dart';
import 'biquote_signalr_client.dart';
import 'biquote_unseen_paper_forward_runner.dart';
import 'frozen_live_a_c5_evaluator.dart';
import 'live_paper_signal_runner.dart';
import 'live_tradeforge_status.dart';
import 'paper_strategy_opportunity.dart';
import '../strategy_library/market_regime_router.dart';
import '../strategy_library/research_strategy_scanner.dart';

/// Local read-only API used by the Flutter UI.
///
/// The backend remains the trading brain. Flutter only consumes this projection.
/// No endpoint can place or execute a broker order.
final class BiQuoteLiveApiServer {
  BiQuoteLiveApiServer({
    required this.feed,
    required this.pipeline,
    required this.signalRunner,
    this.address = '127.0.0.1',
    this.port = 8787,
  }) {
    _runner = BiQuoteUnseenPaperForwardRunner(
      feed: feed,
      pipeline: pipeline,
      onClosedM5: _onClosedM5,
    );
  }

  final BiQuoteRealtimeFeed feed;
  final BiQuoteLiveClosedBarPipeline pipeline;
  final LivePaperSignalRunner signalRunner;
  final String address;
  final int port;

  late final BiQuoteUnseenPaperForwardRunner _runner;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  HttpServer? _server;

  BiQuoteStreamState _streamState = BiQuoteStreamState.disconnected;
  BiQuoteTick? _tick;
  FrozenLiveAC5Evaluation? _lastEvaluation;
  PaperStrategyOpportunity? _latestOpportunity;
  String? _error;
  int _evaluatedM5Count = 0;
  int _aOpportunityCount = 0;
  int _c5OpportunityCount = 0;
  final ResearchStrategyScanner _researchScanner =
      const ResearchStrategyScanner();
  MarketRoute? _marketRoute;
  List<ResearchStrategyObservation> _researchStrategies = const [];

  LiveTradeForgeStatus get status => LiveTradeForgeStatus(
    streamState: _streamState,
    tick: _tick,
    lastEvaluation: _lastEvaluation,
    latestOpportunity: _latestOpportunity,
    evaluatedM5Count: _evaluatedM5Count,
    aOpportunityCount: _aOpportunityCount,
    c5OpportunityCount: _c5OpportunityCount,
    marketRoute: _marketRoute,
    researchStrategies: _researchStrategies,
    error: _error,
  );

  Future<void> start({int warmupPerTimeframe = 500}) async {
    _subscriptions
      ..add(
        feed.ticks.listen((tick) {
          _tick = tick;
          _error = null;
        }),
      )
      ..add(
        feed.states.listen((state) {
          _streamState = state;
        }),
      );

    _server = await HttpServer.bind(address, port);
    _server!.listen(_handleRequest);

    try {
      await _runner.start(warmupPerTimeframe: warmupPerTimeframe);
    } catch (error) {
      _error = '$error';
      rethrow;
    }
  }

  Future<void> _onClosedM5(BiQuoteLiveMarketSnapshot snapshot) async {
    final research = _researchScanner.scan(snapshot);
    _marketRoute = research.$1;
    _researchStrategies = research.$2;
    await signalRunner.onClosedM5(snapshot);
    final evaluation = signalRunner.lastEvaluation;
    _lastEvaluation = evaluation;
    if (evaluation != null) {
      _evaluatedM5Count += 1;
      if (evaluation.a != null) _aOpportunityCount += 1;
      if (evaluation.c5 != null) _c5OpportunityCount += 1;
      final opportunities = evaluation.opportunities.toList(growable: false);
      // `opportunity` means the CURRENT M5 opportunity. Never leave an old
      // signal displayed as if it were still current after a later NO TRADE.
      _latestOpportunity = opportunities.isEmpty ? null : opportunities.last;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _cors(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && request.uri.path == '/api/live') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(status.toJson()));
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && request.uri.path == '/health') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'ok': true,
          'connection': _streamState.name,
        }),
      );
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not found');
    await request.response.close();
  }

  void _cors(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type')
      ..set('Cache-Control', 'no-store');
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _server?.close(force: true);
    await _runner.dispose();
  }
}
