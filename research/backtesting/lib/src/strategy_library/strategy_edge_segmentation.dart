import '../validation/strategy_expectancy_validator.dart';
import 'mainstream_strategy_batch.dart';

final class StrategyEdgeSegmentReport {
  const StrategyEdgeSegmentReport({
    required this.strategyId,
    required this.side,
    required this.regime,
    required this.report,
    required this.byYear,
    required this.rolling,
    required this.overlapRatio,
  });

  final String strategyId;
  final ResearchSide side;
  final String regime;
  final StrategyExpectancyReport report;
  final Map<int, StrategyExpectancyReport> byYear;
  final List<StrategyExpectancyReport> rolling;
  final double overlapRatio;

  bool get hasEvidence => report.resolved >= 100;

  double get rollingPositiveRatio {
    final evidenced = rolling
        .where((r) => r.resolved >= 30)
        .toList(growable: false);
    if (evidenced.isEmpty) {
      return 0;
    }
    return evidenced.where(_positive).length / evidenced.length;
  }

  int get positiveYears =>
      byYear.values.where((r) => r.resolved >= 30 && _positive(r)).length;

  /// Research-only segmentation gate. Passing this gate is not permission to
  /// emit live signals; it only identifies a side + regime hypothesis that is
  /// stable enough for a separate paper-forward experiment.
  bool get segmentationGate {
    final evidencedRolling = rolling.where((r) => r.resolved >= 30).length;
    return hasEvidence &&
        _positive(report) &&
        report.firstHalfNetExpectancyR > 0 &&
        report.secondHalfNetExpectancyR > 0 &&
        positiveYears >= 2 &&
        evidencedRolling >= 4 &&
        rollingPositiveRatio >= .75;
  }

  static bool _positive(StrategyExpectancyReport report) =>
      report.netExpectancyR > 0 && report.profitFactor > 1;
}

final class StrategyEdgeSegmentation {
  const StrategyEdgeSegmentation({this.rollingWindows = 8});

  final int rollingWindows;

  List<StrategyEdgeSegmentReport> evaluate(List<StrategyBatchResult> results) {
    final eligible = results
        .where((r) => r.historicalGate)
        .toList(growable: false);
    final overlapIndex = _buildOverlapIndex(eligible);
    final reports = <StrategyEdgeSegmentReport>[];

    for (final result in eligible) {
      final groups = <String, List<StrategyResearchCase>>{};
      for (final item in result.cases) {
        final key = '${item.candidate.side.name}|${item.candidate.regime}';
        groups.putIfAbsent(key, () => <StrategyResearchCase>[]).add(item);
      }

      for (final entry in groups.entries) {
        final cases = [...entry.value]
          ..sort(
            (a, b) => a.candidate.observedAt.compareTo(b.candidate.observedAt),
          );
        final side = cases.first.candidate.side;
        final regime = cases.first.candidate.regime;
        final trades = cases.map((e) => e.trade).toList(growable: false);
        final byYearCases = <int, List<StrategyTradeResult>>{};
        var overlaps = 0;

        for (final item in cases) {
          final year = item.candidate.observedAt.year;
          byYearCases
              .putIfAbsent(year, () => <StrategyTradeResult>[])
              .add(item.trade);
          if (_overlapsAnotherStrategy(
            item.candidate,
            result.strategy.id,
            overlapIndex,
          )) {
            overlaps++;
          }
        }

        reports.add(
          StrategyEdgeSegmentReport(
            strategyId: result.strategy.id,
            side: side,
            regime: regime,
            report: const StrategyExpectancyValidator().evaluate(trades),
            byYear: {
              for (final year in byYearCases.keys.toList()..sort())
                year: const StrategyExpectancyValidator().evaluate(
                  byYearCases[year]!,
                ),
            },
            rolling: _rolling(cases),
            overlapRatio: cases.isEmpty ? 0 : overlaps / cases.length,
          ),
        );
      }
    }

    reports.sort((a, b) {
      final gate = (b.segmentationGate ? 1 : 0).compareTo(
        a.segmentationGate ? 1 : 0,
      );
      if (gate != 0) {
        return gate;
      }
      return b.report.netExpectancyR.compareTo(a.report.netExpectancyR);
    });
    return reports;
  }

  List<StrategyExpectancyReport> _rolling(List<StrategyResearchCase> cases) {
    if (cases.isEmpty || rollingWindows <= 0) {
      return const [];
    }
    final count = rollingWindows > cases.length ? cases.length : rollingWindows;
    return [
      for (var window = 0; window < count; window++)
        const StrategyExpectancyValidator().evaluate(
          cases
              .sublist(
                (cases.length * window) ~/ count,
                (cases.length * (window + 1)) ~/ count,
              )
              .map((e) => e.trade)
              .toList(growable: false),
        ),
    ];
  }

  Map<String, Set<String>> _buildOverlapIndex(
    List<StrategyBatchResult> results,
  ) {
    final index = <String, Set<String>>{};
    for (final result in results) {
      for (final item in result.cases) {
        final minute =
            item.candidate.observedAt.toUtc().millisecondsSinceEpoch ~/ 60000;
        final key = '$minute|${item.candidate.side.name}';
        index.putIfAbsent(key, () => <String>{}).add(result.strategy.id);
      }
    }
    return index;
  }

  bool _overlapsAnotherStrategy(
    ResearchCandidate candidate,
    String strategyId,
    Map<String, Set<String>> index,
  ) {
    final minute = candidate.observedAt.toUtc().millisecondsSinceEpoch ~/ 60000;
    for (var delta = -15; delta <= 15; delta += 5) {
      final strategies = index['${minute + delta}|${candidate.side.name}'];
      if (strategies != null && strategies.any((id) => id != strategyId)) {
        return true;
      }
    }
    return false;
  }
}
