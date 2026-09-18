import '../validation/strategy_expectancy_validator.dart';
import 'mainstream_strategy_batch.dart';

final class RobustnessSlice {
  const RobustnessSlice({required this.label, required this.report});
  final String label;
  final StrategyExpectancyReport report;
  bool get hasEvidence => report.resolved >= 30;
  bool get positive =>
      hasEvidence && report.netExpectancyR > 0 && report.profitFactor > 1;
}

final class StrategyRobustnessReport {
  const StrategyRobustnessReport({
    required this.strategyId,
    required this.overall,
    required this.bySide,
    required this.byRegime,
    required this.byYear,
    required this.byQuarter,
    required this.rolling,
  });

  final String strategyId;
  final StrategyExpectancyReport overall;
  final List<RobustnessSlice> bySide;
  final List<RobustnessSlice> byRegime;
  final List<RobustnessSlice> byYear;
  final List<RobustnessSlice> byQuarter;
  final List<RobustnessSlice> rolling;

  Iterable<RobustnessSlice> get evidencedSides =>
      bySide.where((s) => s.hasEvidence);
  Iterable<RobustnessSlice> get evidencedYears =>
      byYear.where((s) => s.hasEvidence);
  Iterable<RobustnessSlice> get evidencedRolling =>
      rolling.where((s) => s.hasEvidence);

  double get rollingPositiveRatio {
    final slices = evidencedRolling.toList(growable: false);
    if (slices.isEmpty) return 0;
    return slices.where((s) => s.positive).length / slices.length;
  }

  /// Research gate only. This never promotes a strategy to live signals.
  /// Requires the original historical gate, stable BUY/SELL evidence where
  /// sampled, at least two positive calendar years, and >=75% positive
  /// chronological rolling windows.
  bool get robustnessGate {
    final historical =
        overall.resolved >= 30 &&
        overall.netExpectancyR > 0 &&
        overall.profitFactor > 1 &&
        overall.firstHalfNetExpectancyR > 0 &&
        overall.secondHalfNetExpectancyR > 0;
    final sides = evidencedSides.toList(growable: false);
    final years = evidencedYears.toList(growable: false);
    final rollingSlices = evidencedRolling.toList(growable: false);
    return historical &&
        sides.isNotEmpty &&
        sides.every((s) => s.positive) &&
        years.where((s) => s.positive).length >= 2 &&
        rollingSlices.length >= 4 &&
        rollingPositiveRatio >= .75;
  }
}

final class StrategyRobustnessValidator {
  const StrategyRobustnessValidator({this.rollingWindows = 8});
  final int rollingWindows;

  StrategyRobustnessReport evaluate(StrategyBatchResult result) {
    final ordered = [
      ...result.cases,
    ]..sort((a, b) => a.candidate.observedAt.compareTo(b.candidate.observedAt));
    return StrategyRobustnessReport(
      strategyId: result.strategy.id,
      overall: result.report,
      bySide: _group(ordered, (c) => c.candidate.side.name.toUpperCase()),
      byRegime: _group(ordered, (c) => c.candidate.regime.toUpperCase()),
      byYear: _group(ordered, (c) => '${c.candidate.observedAt.year}'),
      byQuarter: _group(ordered, (c) {
        final time = c.candidate.observedAt;
        return '${time.year}-Q${((time.month - 1) ~/ 3) + 1}';
      }),
      rolling: _rolling(ordered),
    );
  }

  List<RobustnessSlice> _group(
    List<StrategyResearchCase> cases,
    String Function(StrategyResearchCase) keyOf,
  ) {
    final groups = <String, List<StrategyTradeResult>>{};
    for (final item in cases) {
      groups
          .putIfAbsent(keyOf(item), () => <StrategyTradeResult>[])
          .add(item.trade);
    }
    final labels = groups.keys.toList()..sort();
    return [
      for (final label in labels)
        RobustnessSlice(
          label: label,
          report: const StrategyExpectancyValidator().evaluate(groups[label]!),
        ),
    ];
  }

  List<RobustnessSlice> _rolling(List<StrategyResearchCase> cases) {
    if (cases.isEmpty || rollingWindows <= 0) return const [];
    final count = rollingWindows > cases.length ? cases.length : rollingWindows;
    final out = <RobustnessSlice>[];
    for (var window = 0; window < count; window++) {
      final start = (cases.length * window) ~/ count;
      final end = (cases.length * (window + 1)) ~/ count;
      final trades = cases
          .sublist(start, end)
          .map((e) => e.trade)
          .toList(growable: false);
      out.add(
        RobustnessSlice(
          label: 'W${window + 1}',
          report: const StrategyExpectancyValidator().evaluate(trades),
        ),
      );
    }
    return out;
  }
}
