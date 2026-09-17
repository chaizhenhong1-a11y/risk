import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

final class OpportunityGapSignature {
  const OpportunityGapSignature({
    required this.regime,
    required this.h4,
    required this.h1,
    required this.m15,
  });

  final MarketRegime regime;
  final MarketStructure h4;
  final MarketStructure h1;
  final MarketStructure m15;

  String get label =>
      '${regime.name} | H4=${h4.name} H1=${h1.name} M15=${m15.name}';

  @override
  bool operator ==(Object other) =>
      other is OpportunityGapSignature &&
      other.regime == regime &&
      other.h4 == h4 &&
      other.h1 == h1 &&
      other.m15 == m15;

  @override
  int get hashCode => Object.hash(regime, h4, h1, m15);
}

final class OpportunityGapRow {
  const OpportunityGapRow({
    required this.signature,
    required this.observations,
    required this.daysPresent,
    required this.dominantDays,
  });

  final OpportunityGapSignature signature;
  final int observations;
  final int daysPresent;
  final int dominantDays;
}

final class OpportunityGapReport {
  const OpportunityGapReport({
    required this.tradingDays,
    required this.zeroOpportunityDays,
    required this.zeroDayObservations,
    required this.rows,
  });

  final int tradingDays;
  final int zeroOpportunityDays;
  final int zeroDayObservations;
  final List<OpportunityGapRow> rows;
}

/// Scans only days left uncovered by the current A+B+C5 candidate sources.
///
/// It does not invent or tune another strategy. It ranks recurring structural
/// states so the next hypothesis can be chosen from the largest real gap.
final class OpportunityGapScanner {
  final Map<DateTime, _GapDay> _days = {};

  void observe({
    required DateTime observedAt,
    required OpportunityGapSignature signature,
    required bool hasOpportunity,
  }) {
    final date = _date(observedAt);
    final day = _days.putIfAbsent(date, _GapDay.new);
    day.signatures[signature] = (day.signatures[signature] ?? 0) + 1;
    if (hasOpportunity) day.hasOpportunity = true;
  }

  void markOpportunity(DateTime observedAt) {
    _days.putIfAbsent(_date(observedAt), _GapDay.new).hasOpportunity = true;
  }

  OpportunityGapReport finish() {
    final zeroDays = _days.values.where((day) => !day.hasOpportunity).toList();
    final observations = <OpportunityGapSignature, int>{};
    final daysPresent = <OpportunityGapSignature, int>{};
    final dominantDays = <OpportunityGapSignature, int>{};

    for (final day in zeroDays) {
      for (final entry in day.signatures.entries) {
        observations[entry.key] = (observations[entry.key] ?? 0) + entry.value;
        daysPresent[entry.key] = (daysPresent[entry.key] ?? 0) + 1;
      }

      if (day.signatures.isEmpty) continue;
      final ordered = day.signatures.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.label.compareTo(b.key.label);
        });
      dominantDays[ordered.first.key] =
          (dominantDays[ordered.first.key] ?? 0) + 1;
    }

    final rows =
        observations.entries
            .map(
              (entry) => OpportunityGapRow(
                signature: entry.key,
                observations: entry.value,
                daysPresent: daysPresent[entry.key] ?? 0,
                dominantDays: dominantDays[entry.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byDays = b.dominantDays.compareTo(a.dominantDays);
            if (byDays != 0) return byDays;
            final byPresence = b.daysPresent.compareTo(a.daysPresent);
            if (byPresence != 0) return byPresence;
            return b.observations.compareTo(a.observations);
          });

    return OpportunityGapReport(
      tradingDays: _days.length,
      zeroOpportunityDays: zeroDays.length,
      zeroDayObservations: observations.values.fold(
        0,
        (total, value) => total + value,
      ),
      rows: List.unmodifiable(rows),
    );
  }

  DateTime _date(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
}

final class _GapDay {
  bool hasOpportunity = false;
  final Map<OpportunityGapSignature, int> signatures = {};
}
