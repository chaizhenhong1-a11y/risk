import 'package:strategy_engine/strategy_engine.dart';

/// Research-only diagnostics for Strategy C discovery.
///
/// Measures which H4/H1 regimes dominate days where A+B produced no
/// opportunity. This class does not define, tune, or approve Strategy C.
final class StrategyCRegimeGapDiagnostics {
  final Map<DateTime, _DayState> _days = {};

  void observe({
    required DateTime observedAt,
    required MarketRegime regime,
    required bool strategyAOpportunityStarted,
    required bool strategyBOpportunity,
  }) {
    final date = DateTime(observedAt.year, observedAt.month, observedAt.day);
    final day = _days.putIfAbsent(date, _DayState.new);
    day.regimes[regime] = (day.regimes[regime] ?? 0) + 1;
    if (strategyAOpportunityStarted || strategyBOpportunity) {
      day.hadOpportunity = true;
    }
  }

  StrategyCRegimeGapReport finish() {
    final zeroDays = _days.values.where((day) => !day.hadOpportunity).toList();
    final observations = <MarketRegime, int>{
      for (final regime in MarketRegime.values) regime: 0,
    };
    final dominantDays = <MarketRegime, int>{
      for (final regime in MarketRegime.values) regime: 0,
    };

    for (final day in zeroDays) {
      for (final entry in day.regimes.entries) {
        observations[entry.key] = observations[entry.key]! + entry.value;
      }
      if (day.regimes.isEmpty) continue;
      final ordered = day.regimes.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          return byCount != 0 ? byCount : a.key.index.compareTo(b.key.index);
        });
      dominantDays[ordered.first.key] = dominantDays[ordered.first.key]! + 1;
    }

    return StrategyCRegimeGapReport(
      tradingDays: _days.length,
      zeroOpportunityDays: zeroDays.length,
      regimeObservationCounts: observations,
      dominantRegimeDayCounts: dominantDays,
    );
  }
}

final class StrategyCRegimeGapReport {
  StrategyCRegimeGapReport({
    required this.tradingDays,
    required this.zeroOpportunityDays,
    required Map<MarketRegime, int> regimeObservationCounts,
    required Map<MarketRegime, int> dominantRegimeDayCounts,
  }) : regimeObservationCounts = Map.unmodifiable(regimeObservationCounts),
       dominantRegimeDayCounts = Map.unmodifiable(dominantRegimeDayCounts);

  final int tradingDays;
  final int zeroOpportunityDays;
  final Map<MarketRegime, int> regimeObservationCounts;
  final Map<MarketRegime, int> dominantRegimeDayCounts;

  int get zeroDayObservations =>
      regimeObservationCounts.values.fold(0, (a, b) => a + b);

  double observationShare(MarketRegime regime) => zeroDayObservations == 0
      ? 0
      : (regimeObservationCounts[regime] ?? 0) / zeroDayObservations;
}

final class _DayState {
  bool hadOpportunity = false;
  final Map<MarketRegime, int> regimes = {};
}
