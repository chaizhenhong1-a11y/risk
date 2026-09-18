import 'dart:convert';
import 'dart:io';

import 'biquote_live_market_snapshot.dart';
import 'biquote_strategy_candle_adapter.dart';
import '../strategy_library/mainstream_strategy_batch.dart';
import '../strategy_library/paper_forward_segment_portfolio.dart';

/// Durable, anti-lookahead observer for the frozen paper-forward segment portfolio.
///
/// It consumes only the immutable BiQuote CLOSED-M5 snapshot. Historical bars
/// before [startAt] are warm-up context only and can never become forward
/// evidence. Output is a research/paper journal; it cannot emit production
/// BUY/SELL signals.
final class BiQuoteSegmentPaperForwardBridge {
  BiQuoteSegmentPaperForwardBridge({
    required this.startAt,
    required this.stateFile,
    required this.journalFile,
    this.adapter = const BiQuoteStrategyCandleAdapter(),
    this.batch = const MainstreamStrategyBatch(),
    this.portfolio = const PaperForwardSegmentPortfolio(),
  });

  final DateTime startAt;
  final File stateFile;
  final File journalFile;
  final BiQuoteStrategyCandleAdapter adapter;
  final MainstreamStrategyBatch batch;
  final PaperForwardSegmentPortfolio portfolio;

  DateTime? _lastProcessed;
  final Map<String, DateTime> _lastEmitted = <String, DateTime>{};
  DateTime? _lastClusterAt;
  ResearchSide? _lastClusterSide;
  bool _loaded = false;
  DateTime? _lastScanAt;
  Map<String, Map<String, Object?>> _lastScanResults =
      const <String, Map<String, Object?>>{};

  DateTime? get lastScanAt => _lastScanAt;
  Map<String, Map<String, Object?>> get lastScanResults => _lastScanResults;

  Future<void> onClosedM5(BiQuoteLiveMarketSnapshot snapshot) async {
    await _load();
    final observedAt = snapshot.observedAt.toUtc();
    if (!observedAt.isAfter(startAt.toUtc())) return;
    if (_lastProcessed != null && !observedAt.isAfter(_lastProcessed!)) return;

    final visible = adapter.convertAll(snapshot.m5);
    final discovered = batch.discoverAtClose(visible);
    final selected = <PaperForwardPortfolioCandidate>[];
    final scanResults = <String, Map<String, Object?>>{
      for (final definition in portfolio.definitions)
        definition.id: <String, Object?>{
          'result': 'NO_TRADE',
          'reason': '本根 CLOSED M5 已完成扫描；未形成该策略固定方向与市场状态下的完整 setup。',
          'lastEvaluatedAt': observedAt.toIso8601String(),
          'mode': 'paper_forward',
          'requiredSetup':
              '${definition.strategyId} · ${definition.side.name.toUpperCase()} · ${definition.regime.toUpperCase()}',
        },
    };

    for (final candidate in discovered) {
      final definition = portfolio.definitions.where(
        (item) => item.matches(candidate),
      );
      if (definition.isEmpty) continue;

      final matched = definition.single;
      scanResults[matched.id] = <String, Object?>{
        'result': candidate.side.name.toUpperCase(),
        'reason': '冻结 segment 条件触发，候选已进入 Paper Forward。',
        'lastEvaluatedAt': observedAt.toIso8601String(),
        'mode': 'paper_forward',
        'entry': candidate.entry,
        'stopLoss': candidate.stop,
        'takeProfit': candidate.target,
        'riskReward': candidate.rewardRisk,
      };

      final episodeKey = '${candidate.strategyId}|${candidate.side.name}';
      final previous = _lastEmitted[episodeKey];
      if (previous != null &&
          candidate.observedAt.difference(previous).inMinutes <= 15) {
        continue;
      }
      _lastEmitted[episodeKey] = candidate.observedAt.toUtc();
      selected.add(
        PaperForwardPortfolioCandidate(
          candidate: candidate,
          segmentId: definition.single.id,
        ),
      );
    }

    final accepted = <PaperForwardPortfolioCandidate>[];
    for (final item in selected) {
      final sameCluster =
          _lastClusterAt != null &&
          _lastClusterSide == item.candidate.side &&
          item.candidate.observedAt.difference(_lastClusterAt!).inMinutes <=
              portfolio.clusterMinutes;
      if (!sameCluster) {
        accepted.add(item);
        _lastClusterAt = item.candidate.observedAt.toUtc();
        _lastClusterSide = item.candidate.side;
      }
    }

    if (accepted.isNotEmpty) {
      await journalFile.parent.create(recursive: true);
      final sink = journalFile.openWrite(mode: FileMode.append);
      try {
        for (final item in accepted) {
          sink.writeln(
            jsonEncode(<String, Object>{
              'schema': 1,
              'kind': 'SEGMENT_PAPER_FORWARD',
              'observedAt': item.candidate.observedAt.toUtc().toIso8601String(),
              'segmentId': item.segmentId,
              'strategyId': item.candidate.strategyId,
              'side': item.candidate.side.name.toUpperCase(),
              'regime': item.candidate.regime.toUpperCase(),
              'entry': item.candidate.entry,
              'stop': item.candidate.stop,
              'target': item.candidate.target,
              'rewardRisk': item.candidate.rewardRisk,
            }),
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    }

    // Publish scan diagnostics only after this CLOSED M5 completed.
    _lastScanAt = observedAt;
    _lastScanResults = Map.unmodifiable(scanResults);

    // Advance only after journal persistence succeeds.
    _lastProcessed = observedAt;
    await _save();
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    if (!stateFile.existsSync()) return;
    final decoded = jsonDecode(await stateFile.readAsString());
    if (decoded is! Map<String, dynamic>) return;
    final persistedStart = DateTime.tryParse(
      decoded['startAt']?.toString() ?? '',
    );
    if (persistedStart != null && persistedStart.toUtc() != startAt.toUtc()) {
      throw StateError('Paper-forward startAt is immutable once persisted.');
    }
    _lastProcessed = DateTime.tryParse(
      decoded['lastProcessed']?.toString() ?? '',
    )?.toUtc();
    _lastClusterAt = DateTime.tryParse(
      decoded['lastClusterAt']?.toString() ?? '',
    )?.toUtc();
    final side = decoded['lastClusterSide']?.toString();
    if (side != null) {
      _lastClusterSide = ResearchSide.values
          .where((v) => v.name == side)
          .firstOrNull;
    }
    final emitted = decoded['lastEmitted'];
    if (emitted is Map) {
      for (final entry in emitted.entries) {
        final value = DateTime.tryParse(entry.value.toString());
        if (value != null) _lastEmitted[entry.key.toString()] = value.toUtc();
      }
    }
  }

  Future<void> _save() async {
    await stateFile.parent.create(recursive: true);
    final temp = File('${stateFile.path}.tmp');
    await temp.writeAsString(
      jsonEncode(<String, Object?>{
        'schema': 1,
        'startAt': startAt.toUtc().toIso8601String(),
        'lastProcessed': _lastProcessed?.toIso8601String(),
        'lastClusterAt': _lastClusterAt?.toIso8601String(),
        'lastClusterSide': _lastClusterSide?.name,
        'lastEmitted': <String, String>{
          for (final entry in _lastEmitted.entries)
            entry.key: entry.value.toUtc().toIso8601String(),
        },
      }),
      flush: true,
    );
    if (stateFile.existsSync()) await stateFile.delete();
    await temp.rename(stateFile.path);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
