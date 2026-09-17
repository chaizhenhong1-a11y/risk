enum CoverageSource { strategyA, strategyB, strategyC5 }

enum CoverageDirection { buy, sell }

final class CoverageEvent {
  const CoverageEvent({
    required this.time,
    required this.direction,
    required this.source,
  });
  final DateTime time;
  final CoverageDirection direction;
  final CoverageSource source;
}

final class StrategyAbcCoverageSummary {
  const StrategyAbcCoverageSummary({
    required this.sourceCounts,
    required this.sameDirectionOverlaps,
    required this.oppositeDirectionConflicts,
    required this.uniqueOpportunities,
    required this.dailyCounts,
  });
  final Map<CoverageSource, int> sourceCounts;
  final int sameDirectionOverlaps;
  final int oppositeDirectionConflicts;
  final int uniqueOpportunities;
  final List<int> dailyCounts;
  double get averagePerDay =>
      dailyCounts.isEmpty ? 0 : uniqueOpportunities / dailyCounts.length;
}

final class StrategyAbcCoverageAnalyzer {
  const StrategyAbcCoverageAnalyzer();

  StrategyAbcCoverageSummary analyze({
    required Iterable<DateTime> tradingDates,
    required Iterable<CoverageEvent> events,
  }) {
    String day(DateTime t) =>
        '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final all = events.toList();
    final groups = <String, List<CoverageEvent>>{};
    for (final e in all) {
      groups.putIfAbsent(e.time.toIso8601String(), () => []).add(e);
    }
    var overlaps = 0, conflicts = 0;
    final perDay = <String, int>{};
    for (final g in groups.values) {
      final dirs = g.map((e) => e.direction).toSet();
      final sources = g.map((e) => e.source).toSet();
      if (dirs.length > 1) {
        conflicts++;
      } else if (sources.length > 1) {
        overlaps++;
      }
      final k = day(g.first.time);
      perDay[k] = (perDay[k] ?? 0) + 1;
    }
    final dates =
        tradingDates
            .map((d) => DateTime.utc(d.year, d.month, d.day))
            .toSet()
            .toList()
          ..sort();
    return StrategyAbcCoverageSummary(
      sourceCounts: {
        for (final s in CoverageSource.values)
          s: all.where((e) => e.source == s).length,
      },
      sameDirectionOverlaps: overlaps,
      oppositeDirectionConflicts: conflicts,
      uniqueOpportunities: groups.length,
      dailyCounts: [for (final d in dates) perDay[day(d)] ?? 0],
    );
  }
}
