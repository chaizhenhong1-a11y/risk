import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'biquote_market_data.dart';
import 'biquote_realtime_feed.dart';
import 'biquote_signalr_client.dart';
import 'biquote_live_paper_session.dart';
import 'paper_strategy_opportunity.dart';
import 'paper_signal.dart';
import 'paper_signal_journal.dart';
import 'paper_exposure_control.dart';
import 'paper_trade_result_journal.dart';
import '../strategy_library/paper_forward_segment_portfolio.dart';

/// HTTP projection of the same live BiQuote feed used by paper-forward.
/// It is read-only and never sends broker orders.
final class BiQuoteUnifiedLiveApiServer {
  BiQuoteUnifiedLiveApiServer({
    required this.feed,
    required this.session,
    required this.segmentCandidateJournal,
    this.address = '127.0.0.1',
    this.port = 8787,
  });

  final BiQuoteRealtimeFeed feed;
  final BiQuoteLivePaperSession session;
  final File segmentCandidateJournal;
  final String address;
  final int port;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  HttpServer? _server;
  BiQuoteStreamState _streamState = BiQuoteStreamState.disconnected;
  BiQuoteTick? _tick;
  String? _error;

  Future<void> start() async {
    _subscriptions.add(
      feed.ticks.listen((tick) {
        _tick = tick;
        _error = null;
      }, onError: (Object error, StackTrace stackTrace) => _error = '$error'),
    );
    _subscriptions.add(
      feed.states.listen(
        (state) => _streamState = state,
        onError: (Object error, StackTrace stackTrace) => _error = '$error',
      ),
    );

    _server = await HttpServer.bind(address, port);
    _server!.listen(_handleRequest);
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
      request.response.write(jsonEncode(await _statusJson()));
      await request.response.close();
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/health') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'ok': true,
          'connection': _streamState.name,
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
      'connection': _streamState.name,
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
      value.addAll(<String, Object?>{
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
    final ids = const PaperForwardSegmentPortfolio().definitions
        .map((item) => item.id)
        .toList(growable: false);
    final actual = session.segmentSession.bridge.lastScanResults;
    return <String, Object?>{
      for (final id in ids)
        id:
            actual[id] ??
            <String, Object?>{
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

    final signalJournal = const PaperSignalJournal();
    final resultJournal = const PaperTradeResultJournal();
    final signals = signalJournal.readAll(session.signalRunner.signalsFile);
    final results = <String, dynamic>{
      for (final item in resultJournal.readAll(
        session.signalRunner.resultsFile,
      ))
        item.signalId: item,
    };
    for (final signal in signals) {
      final result = results[signal.id];
      history.add(<String, Object?>{
        'id': signal.id,
        'source': 'production_paper',
        'symbol': signal.symbol,
        'strategy': signal.strategy,
        'side': signal.side.name.toUpperCase(),
        'observedAt': signal.observedAt.toUtc().toIso8601String(),
        'entry': signal.entry,
        'stopLoss': signal.stopLoss,
        'takeProfit': signal.takeProfit,
        'riskReward': signal.rewardRisk,
        'reason': signal.reason,
        'status': result == null
            ? _paperStatusName(signal.status)
            : _paperStatusName(result.status),
        'resolvedAt': result?.resolvedAt.toUtc().toIso8601String(),
        'realizedR': result?.grossR,
      });
    }

    final lifecycleById = await _segmentLifecycleById();
    if (segmentCandidateJournal.existsSync()) {
      await for (final line
          in segmentCandidateJournal
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        final decoded = jsonDecode(line);
        if (decoded is! Map) continue;
        final row = Map<String, dynamic>.from(decoded);
        if (row['kind'] != 'SEGMENT_PAPER_FORWARD') continue;
        final observedAt = DateTime.parse(row['observedAt'].toString()).toUtc();
        final segmentId = row['segmentId'].toString();
        final id = '$segmentId|${observedAt.toIso8601String()}';
        final lifecycle = lifecycleById[id];
        history.add(<String, Object?>{
          'id': id,
          'source': 'paper_forward',
          'symbol': 'XAUUSD',
          'strategy':
              row['strategyId']?.toString() ?? segmentId.split('|').first,
          'side': row['side']?.toString().toUpperCase(),
          'segmentId': segmentId,
          'regime': row['regime']?.toString(),
          'observedAt': observedAt.toIso8601String(),
          'entry': row['entry'],
          'stopLoss': row['stop'],
          'takeProfit': row['target'],
          'riskReward': row['rewardRisk'],
          'reason': '冻结 segment 条件触发，候选已进入 Paper Forward。',
          'status': lifecycle?['status']?.toString() ?? 'pending',
          'resolvedAt': lifecycle?['resolvedAt'],
          'realizedR': lifecycle?['realizedR'],
        });
      }
    }

    final byId = <String, Map<String, Object?>>{};
    for (final item in history) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      byId[id] = item;
    }
    final deduplicated = byId.values.toList(growable: false);
    final exposure = const PaperExposureControl().classify(
      deduplicated.map(
        (item) => PaperExposureRecord(
          id: item['id'].toString(),
          strategy: item['strategy'].toString(),
          side: item['side'].toString().toUpperCase(),
          observedAt: DateTime.parse(item['observedAt'].toString()).toUtc(),
          resolvedAt: item['resolvedAt'] == null
              ? null
              : DateTime.parse(item['resolvedAt'].toString()).toUtc(),
        ),
      ),
    );

    for (final item in deduplicated) {
      final decision = exposure[item['id'].toString()];
      if (decision == null) continue;
      item.addAll(<String, Object?>{
        'exposureStatus': decision.exposureStatus,
        'independentEvidence': decision.independentEvidence,
        'executionEligible': decision.executionEligible,
        'portfolioOverlap': decision.portfolioOverlap,
        'exposureGroupId': decision.exposureGroupId,
        'overlapsSignalId': decision.overlapsSignalId,
      });
    }

    deduplicated.sort(
      (a, b) =>
          b['observedAt'].toString().compareTo(a['observedAt'].toString()),
    );
    return deduplicated;
  }

  String _paperStatusName(PaperSignalStatus status) => switch (status) {
    PaperSignalStatus.pending => 'pending',
    PaperSignalStatus.triggered => 'triggered',
    PaperSignalStatus.targetHit => 'targetHit',
    PaperSignalStatus.stopHit => 'stopHit',
    PaperSignalStatus.expired => 'expired',
    PaperSignalStatus.ambiguous => 'ambiguous',
    PaperSignalStatus.rejected => 'rejected',
  };

  Future<Map<String, Map<String, dynamic>>> _segmentLifecycleById() async {
    final stateFile = session.segmentSession.lifecycle.stateFile;
    if (!stateFile.existsSync()) return const <String, Map<String, dynamic>>{};
    final decoded = jsonDecode(await stateFile.readAsString());
    if (decoded is! Map) return const <String, Map<String, dynamic>>{};
    final raw = decoded['positions'];
    if (raw is! List) return const <String, Map<String, dynamic>>{};
    final result = <String, Map<String, dynamic>>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final id = row['id']?.toString();
      if (id == null) continue;
      final status = row['status']?.toString();
      row['realizedR'] = switch (status) {
        'targetHit' => (row['rewardRisk'] as num?)?.toDouble(),
        'stopHit' => -1.0,
        'expired' => null,
        _ => null,
      };
      result[id] = row;
    }
    return result;
  }

  Map<String, Object?> _opportunityJson(PaperStrategyOpportunity item) {
    final risk = (item.entry - item.stopLoss).abs();
    final reward = (item.takeProfit - item.entry).abs();
    return <String, Object?>{
      'symbol': item.symbol,
      'strategy': item.strategy,
      'side': item.side.name,
      'observedAt': item.observedAt.toIso8601String(),
      'entry': item.entry,
      'stopLoss': item.stopLoss,
      'takeProfit': item.takeProfit,
      'riskReward': risk == 0 ? 0 : reward / risk,
      'reason': item.reason,
    };
  }

  Future<int> _countLines(File file) async {
    if (!file.existsSync()) return 0;
    var count = 0;
    await for (final line
        in file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isNotEmpty) count++;
    }
    return count;
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
    _server = null;
  }
}
