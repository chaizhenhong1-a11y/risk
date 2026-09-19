import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../strategy_library/paper_forward_segment_portfolio.dart';
import 'biquote_live_paper_session.dart';
import 'biquote_market_data.dart';
import 'biquote_realtime_feed.dart';
import 'independent_candidate_fundamental_coordinator.dart';
import 'paper_exposure_control.dart';
import 'paper_signal.dart';
import 'paper_signal_journal.dart';
import 'paper_strategy_opportunity.dart';
import 'paper_trade_result_journal.dart';

final class BiQuoteUnifiedLiveApiServer {
  BiQuoteUnifiedLiveApiServer({
    required this.feed,
    required this.session,
    required this.segmentCandidateJournal,
    this.fundamentalCoordinator,
    this.address = '127.0.0.1',
    this.port = 8787,
  });

  final BiQuoteRealtimeFeed feed;
  final BiQuoteLivePaperSession session;
  final File segmentCandidateJournal;
  final IndependentCandidateFundamentalCoordinator? fundamentalCoordinator;
  final String address;
  final int port;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  HttpServer? _server;
  BiQuoteTick? _tick;
  String? _error;

  Future<void> start() async {
    _subscriptions.add(
      feed.ticks.listen((tick) {
        _tick = tick;
        _error = null;
      }, onError: (Object error, StackTrace stackTrace) => _error = '$error'),
    );
    _server = await HttpServer.bind(address, port);
    _server!.listen(_handleRequest);
  }

  String get _connectionName => switch (feed.runtimeState) {
    BiQuoteRuntimeState.live => 'connected',
    BiQuoteRuntimeState.marketClosed => 'marketClosed',
    BiQuoteRuntimeState.connecting => 'connecting',
    BiQuoteRuntimeState.offline => 'disconnected',
    BiQuoteRuntimeState.stopped => 'disconnected',
  };

  String get _marketStatus => switch (feed.runtimeState) {
    BiQuoteRuntimeState.live => 'OPEN',
    BiQuoteRuntimeState.marketClosed => 'CLOSED',
    _ => 'UNKNOWN',
  };

  String get _providerStatus =>
      feed.runtimeState == BiQuoteRuntimeState.offline ? 'OFFLINE' : 'ONLINE';

  Future<void> _handleRequest(HttpRequest request) async {
    _cors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/api/live') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(await _statusJson()));
      await request.response.close();
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/health') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'ok': true,
          'connection': _connectionName,
          'marketStatus': _marketStatus,
          'providerStatus': _providerStatus,
          'hasTick': _tick != null,
        }),
      );
      await request.response.close();
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Future<Map<String, Object?>> _statusJson() async {
    final quote = _tick;
    final evaluation = session.signalRunner.lastEvaluation;
    final opportunities =
        evaluation?.opportunities.toList(growable: false) ??
        const <PaperStrategyOpportunity>[];
    final latest = opportunities.isEmpty ? null : opportunities.last;
    final evaluatedAt = evaluation?.observedAt.toIso8601String();

    return <String, Object?>{
      'connection': _connectionName,
      'marketStatus': _marketStatus,
      'providerStatus': _providerStatus,
      'symbol': quote?.symbol ?? 'XAUUSD',
      'quote': quote == null
          ? null
          : <String, Object?>{
              'bid': quote.bid,
              'ask': quote.ask,
              'mid': quote.mid,
              'timestamp': quote.timestamp.toIso8601String(),
              'source': quote.source,
            },
      'warmupM5Count': session.warmupM5Count,
      'evaluatedM5Count': session.evaluatedM5Count,
      'scanCompletedCount': session.lastEvaluatedAt == null
          ? 0
          : 2 + const PaperForwardSegmentPortfolio().definitions.length,
      'scanStrategyCount':
          2 + const PaperForwardSegmentPortfolio().definitions.length,
      'lastEvaluatedAt': session.lastEvaluatedAt?.toIso8601String(),
      'strategies': <String, Object?>{
        'A': _frozenStatus(
          evaluatedAt,
          evaluation?.aDiagnostic.result,
          evaluation?.aDiagnostic.reason,
          evaluation?.a,
        ),
        'C5': _frozenStatus(
          evaluatedAt,
          evaluation?.c5Diagnostic.result,
          evaluation?.c5Diagnostic.reason,
          evaluation?.c5,
        ),
        ..._segmentStatuses(),
      },
      'segmentPaperForward': <String, Object?>{
        'candidateCount': await _countLines(segmentCandidateJournal),
        'mode': 'paper_forward',
      },
      'signalHistory': await _signalHistory(),
      'opportunity': latest == null ? null : _opportunityJson(latest),
      'error': _error,
    };
  }

  Map<String, Object?> _frozenStatus(
    String? at,
    String? result,
    String? reason,
    PaperStrategyOpportunity? opportunity,
  ) {
    final value = <String, Object?>{
      'result': result ?? 'WAITING',
      'reason': reason ?? '等待首个 CLOSED M5。',
      'status': at == null ? 'waiting' : 'evaluated',
      'lastEvaluatedAt': at,
      'mode': 'production',
    };
    if (opportunity != null) {
      value.addAll({
        'result': opportunity.side.name.toUpperCase(),
        'entry': opportunity.entry,
        'stopLoss': opportunity.stopLoss,
        'takeProfit': opportunity.takeProfit,
        'riskReward':
            (opportunity.takeProfit - opportunity.entry).abs() /
            (opportunity.entry - opportunity.stopLoss).abs(),
      });
    }
    return value;
  }

  Map<String, Object?> _segmentStatuses() {
    final ids = const PaperForwardSegmentPortfolio().definitions.map(
      (e) => e.id,
    );
    final actual = session.segmentSession.bridge.lastScanResults;
    return {
      for (final id in ids)
        id:
            actual[id] ??
            {
              'result': 'WAITING',
              'reason': '等待首个 CLOSED M5。',
              'status': 'waiting',
              'lastEvaluatedAt': null,
              'mode': 'paper_forward',
            },
    };
  }

  Future<List<Map<String, Object?>>> _signalHistory() async {
    final history = <Map<String, Object?>>[];
    final sj = const PaperSignalJournal();
    final rj = const PaperTradeResultJournal();
    final signals = sj.readAll(session.signalRunner.signalsFile);
    final results = {
      for (final x in rj.readAll(session.signalRunner.resultsFile))
        x.signalId: x,
    };
    for (final s in signals) {
      final r = results[s.id];
      history.add({
        'id': s.id,
        'source': 'production_paper',
        'symbol': s.symbol,
        'strategy': s.strategy,
        'side': s.side.name.toUpperCase(),
        'observedAt': s.observedAt.toUtc().toIso8601String(),
        'entry': s.entry,
        'stopLoss': s.stopLoss,
        'takeProfit': s.takeProfit,
        'riskReward': s.rewardRisk,
        'reason': s.reason,
        'status': r == null
            ? _paperStatusName(s.status)
            : _paperStatusName(r.status),
        'resolvedAt': r?.resolvedAt.toUtc().toIso8601String(),
        'realizedR': r?.grossR,
      });
    }
    final lifecycle = await _segmentLifecycleById();
    if (segmentCandidateJournal.existsSync()) {
      await for (final line
          in segmentCandidateJournal
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        final d = jsonDecode(line);
        if (d is! Map) continue;
        final row = Map<String, dynamic>.from(d);
        if (row['kind'] != 'SEGMENT_PAPER_FORWARD') continue;
        final at = DateTime.parse(row['observedAt'].toString()).toUtc();
        final sid = row['segmentId'].toString();
        final id = '$sid|${at.toIso8601String()}';
        final life = lifecycle[id];
        history.add({
          'id': id,
          'source': 'paper_forward',
          'symbol': 'XAUUSD',
          'strategy': row['strategyId']?.toString() ?? sid.split('|').first,
          'side': row['side']?.toString().toUpperCase(),
          'segmentId': sid,
          'regime': row['regime']?.toString(),
          'observedAt': at.toIso8601String(),
          'entry': row['entry'],
          'stopLoss': row['stop'],
          'takeProfit': row['target'],
          'riskReward': row['rewardRisk'],
          'reason': '冻结 segment 条件触发，候选已进入 Paper Forward。',
          'status': life?['status']?.toString() ?? 'pending',
          'resolvedAt': life?['resolvedAt'],
          'realizedR': life?['realizedR'],
        });
      }
    }
    final byId = <String, Map<String, Object?>>{};
    for (final x in history) {
      final id = x['id']?.toString();
      if (id != null && id.isNotEmpty) byId[id] = x;
    }
    final list = byId.values.toList(growable: false);
    final exposure = const PaperExposureControl().classify(
      list.map(
        (x) => PaperExposureRecord(
          id: x['id'].toString(),
          strategy: x['strategy'].toString(),
          side: x['side'].toString().toUpperCase(),
          observedAt: DateTime.parse(x['observedAt'].toString()).toUtc(),
          resolvedAt: x['resolvedAt'] == null
              ? null
              : DateTime.parse(x['resolvedAt'].toString()).toUtc(),
        ),
      ),
    );
    for (final x in list) {
      final d = exposure[x['id'].toString()];
      if (d != null) {
        x.addAll({
          'exposureStatus': d.exposureStatus,
          'independentEvidence': d.independentEvidence,
          'executionEligible': d.executionEligible,
          'portfolioOverlap': d.portfolioOverlap,
          'exposureGroupId': d.exposureGroupId,
          'overlapsSignalId': d.overlapsSignalId,
        });
      }
    }
    await fundamentalCoordinator?.enrich(list);
    list.sort(
      (a, b) =>
          b['observedAt'].toString().compareTo(a['observedAt'].toString()),
    );
    return list;
  }

  String _paperStatusName(PaperSignalStatus s) => switch (s) {
    PaperSignalStatus.pending => 'pending',
    PaperSignalStatus.triggered => 'triggered',
    PaperSignalStatus.targetHit => 'targetHit',
    PaperSignalStatus.stopHit => 'stopHit',
    PaperSignalStatus.expired => 'expired',
    PaperSignalStatus.ambiguous => 'ambiguous',
    PaperSignalStatus.rejected => 'rejected',
  };

  Future<Map<String, Map<String, dynamic>>> _segmentLifecycleById() async {
    final f = session.segmentSession.lifecycle.stateFile;
    if (!f.existsSync()) return const {};
    final d = jsonDecode(await f.readAsString());
    if (d is! Map) return const {};
    final raw = d['positions'];
    if (raw is! List) return const {};
    final out = <String, Map<String, dynamic>>{};
    for (final x in raw) {
      if (x is! Map) continue;
      final row = Map<String, dynamic>.from(x);
      final id = row['id']?.toString();
      if (id == null) continue;
      final s = row['status']?.toString();
      row['realizedR'] = switch (s) {
        'targetHit' => (row['rewardRisk'] as num?)?.toDouble(),
        'stopHit' => -1.0,
        'expired' => null,
        _ => null,
      };
      out[id] = row;
    }
    return out;
  }

  Map<String, Object?> _opportunityJson(PaperStrategyOpportunity x) {
    final risk = (x.entry - x.stopLoss).abs();
    final reward = (x.takeProfit - x.entry).abs();
    return {
      'symbol': x.symbol,
      'strategy': x.strategy,
      'side': x.side.name,
      'observedAt': x.observedAt.toIso8601String(),
      'entry': x.entry,
      'stopLoss': x.stopLoss,
      'takeProfit': x.takeProfit,
      'riskReward': risk == 0 ? 0 : reward / risk,
      'reason': x.reason,
    };
  }

  Future<int> _countLines(File f) async {
    if (!f.existsSync()) return 0;
    var n = 0;
    await for (final line
        in f
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isNotEmpty) n++;
    }
    return n;
  }

  void _cors(HttpResponse r) {
    r.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type')
      ..set('Cache-Control', 'no-store');
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
