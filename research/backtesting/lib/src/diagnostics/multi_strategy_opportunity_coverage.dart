import 'package:strategy_engine/strategy_engine.dart';

final class MultiStrategyOpportunityCoverage {
  MultiStrategyOpportunityCoverage({
    this.symbol = 'XAUUSD',
    this.candidatePool = const StrategyCandidatePool(),
  });

  final String symbol;
  final StrategyCandidatePool candidatePool;
  final List<StrategyOpportunityCandidate> _candidates = [];
  final Set<DateTime> _dates = {};
  bool _previousAEligible = false;
  int _aCount = 0;
  int _bCount = 0;

  void observeTradingDate(DateTime time) => _dates.add(_date(time));

  void observeStrategyA({
    required DateTime observedAt,
    required bool eligible,
    required TradingBias bias,
  }) {
    if (eligible && !_previousAEligible) {
      _aCount++;
      _add(
        observedAt,
        StrategyRouteId.trendPullbackStructureConfirmation,
        bias,
      );
    }
    _previousAEligible = eligible;
  }

  void observeStrategyB({
    required DateTime observedAt,
    required bool eligible,
    required TradingBias bias,
  }) {
    if (!eligible) return;
    _bCount++;
    _add(observedAt, StrategyRouteId.correctionContinuation, bias);
  }

  void _add(DateTime time, StrategyRouteId strategy, TradingBias bias) {
    _candidates.add(
      StrategyOpportunityCandidate(
        symbol: symbol,
        observedAt: time,
        strategy: strategy,
        bias: bias,
      ),
    );
  }

  MultiStrategyOpportunityCoverageReport finish() {
    final pooled = candidatePool.combine(_candidates);
    final daily = <DateTime, int>{for (final date in _dates) date: 0};
    for (final opportunity in pooled.opportunities) {
      final date = _date(opportunity.observedAt);
      daily[date] = (daily[date] ?? 0) + 1;
    }

    final counts = daily.values.toList()..sort();
    var zero = 0, one = 0, two = 0, threePlus = 0;
    for (final count in counts) {
      if (count == 0) {
        zero++;
      } else if (count == 1) {
        one++;
      } else if (count == 2) {
        two++;
      } else {
        threePlus++;
      }
    }

    final median = counts.isEmpty
        ? 0.0
        : counts.length.isOdd
        ? counts[counts.length ~/ 2].toDouble()
        : (counts[counts.length ~/ 2 - 1] + counts[counts.length ~/ 2]) / 2;

    return MultiStrategyOpportunityCoverageReport(
      strategyACandidates: _aCount,
      strategyBCandidates: _bCount,
      sameDirectionOverlaps: pooled.opportunities
          .where((item) => item.hasMultipleSources)
          .length,
      conflicts: pooled.conflicts.length,
      uniqueOpportunities: pooled.opportunities.length,
      observedTradingDays: daily.length,
      averageOpportunitiesPerDay: daily.isEmpty
          ? 0
          : pooled.opportunities.length / daily.length,
      medianOpportunitiesPerDay: median,
      zeroOpportunityDays: zero,
      oneOpportunityDays: one,
      twoOpportunityDays: two,
      threePlusOpportunityDays: threePlus,
    );
  }

  DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

final class MultiStrategyOpportunityCoverageReport {
  const MultiStrategyOpportunityCoverageReport({
    required this.strategyACandidates,
    required this.strategyBCandidates,
    required this.sameDirectionOverlaps,
    required this.conflicts,
    required this.uniqueOpportunities,
    required this.observedTradingDays,
    required this.averageOpportunitiesPerDay,
    required this.medianOpportunitiesPerDay,
    required this.zeroOpportunityDays,
    required this.oneOpportunityDays,
    required this.twoOpportunityDays,
    required this.threePlusOpportunityDays,
  });

  final int strategyACandidates;
  final int strategyBCandidates;
  final int sameDirectionOverlaps;
  final int conflicts;
  final int uniqueOpportunities;
  final int observedTradingDays;
  final double averageOpportunitiesPerDay;
  final double medianOpportunitiesPerDay;
  final int zeroOpportunityDays;
  final int oneOpportunityDays;
  final int twoOpportunityDays;
  final int threePlusOpportunityDays;
}
