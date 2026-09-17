import 'package:technical_analysis/technical_analysis.dart';

enum StrategyCHypothesisId {
  c1BullishTrendRecovery,
  c2BearishTrendRecovery,
  c3BearishCorrectionContinuation,
}

enum StrategyCExpectedDirection { bullish, bearish }

final class StrategyCHypothesisCandidate {
  const StrategyCHypothesisCandidate({
    required this.id,
    required this.expectedDirection,
    required this.observationIndex,
    required this.observationTime,
    required this.entryClose,
  });

  final StrategyCHypothesisId id;
  final StrategyCExpectedDirection expectedDirection;
  final int observationIndex;
  final DateTime observationTime;
  final double entryClose;
}

final class StrategyCHypothesisResult {
  const StrategyCHypothesisResult({
    required this.candidate,
    required this.return12,
    required this.return24,
    required this.return48,
    required this.mfe48,
    required this.mae48,
    required this.resolved12,
    required this.resolved24,
    required this.resolved48,
  });

  final StrategyCHypothesisCandidate candidate;
  final double? return12;
  final double? return24;
  final double? return48;
  final double? mfe48;
  final double? mae48;
  final bool resolved12;
  final bool resolved24;
  final bool resolved48;

  bool? directionCorrect(double? value) {
    if (value == null) return null;
    return switch (candidate.expectedDirection) {
      StrategyCExpectedDirection.bullish => value > 0,
      StrategyCExpectedDirection.bearish => value < 0,
    };
  }
}

final class StrategyCHypothesisSummary {
  const StrategyCHypothesisSummary({
    required this.id,
    required this.candidates,
    required this.correct12,
    required this.resolved12,
    required this.correct24,
    required this.resolved24,
    required this.correct48,
    required this.resolved48,
    required this.averageMfe48,
    required this.averageMae48,
  });

  final StrategyCHypothesisId id;
  final int candidates;
  final int correct12;
  final int resolved12;
  final int correct24;
  final int resolved24;
  final int correct48;
  final int resolved48;
  final double averageMfe48;
  final double averageMae48;

  double share(int correct, int resolved) =>
      resolved == 0 ? 0 : correct / resolved;
}

final class StrategyCHypothesisValidation {
  const StrategyCHypothesisValidation();

  StrategyCHypothesisSummary summarize(
    StrategyCHypothesisId id,
    Iterable<StrategyCHypothesisResult> results,
  ) {
    final rows = results.where((result) => result.candidate.id == id).toList();

    int correct12 = 0, resolved12 = 0;
    int correct24 = 0, resolved24 = 0;
    int correct48 = 0, resolved48 = 0;
    var mfeSum = 0.0, maeSum = 0.0, excursionCount = 0;

    for (final row in rows) {
      final c12 = row.directionCorrect(row.return12);
      if (c12 != null) {
        resolved12++;
        if (c12) correct12++;
      }
      final c24 = row.directionCorrect(row.return24);
      if (c24 != null) {
        resolved24++;
        if (c24) correct24++;
      }
      final c48 = row.directionCorrect(row.return48);
      if (c48 != null) {
        resolved48++;
        if (c48) correct48++;
      }
      if (row.mfe48 != null && row.mae48 != null) {
        mfeSum += row.mfe48!;
        maeSum += row.mae48!;
        excursionCount++;
      }
    }

    return StrategyCHypothesisSummary(
      id: id,
      candidates: rows.length,
      correct12: correct12,
      resolved12: resolved12,
      correct24: correct24,
      resolved24: resolved24,
      correct48: correct48,
      resolved48: resolved48,
      averageMfe48: excursionCount == 0 ? 0 : mfeSum / excursionCount,
      averageMae48: excursionCount == 0 ? 0 : maeSum / excursionCount,
    );
  }

  static bool matches({
    required StrategyCHypothesisId id,
    required MarketStructure h4,
    required MarketStructure h1,
    required MarketStructure m15,
    required bool supportSweep,
    required bool resistanceSweep,
    required bool equalLowSweep,
    required bool equalHighSweep,
  }) {
    final noSweep =
        !supportSweep && !resistanceSweep && !equalLowSweep && !equalHighSweep;
    final dualLevelSweep =
        supportSweep && resistanceSweep && !equalLowSweep && !equalHighSweep;

    return switch (id) {
      StrategyCHypothesisId.c1BullishTrendRecovery =>
        h4 == MarketStructure.bullish &&
            h1 == MarketStructure.neutral &&
            m15 == MarketStructure.bullish &&
            noSweep,
      StrategyCHypothesisId.c2BearishTrendRecovery =>
        h4 == MarketStructure.bearish &&
            h1 == MarketStructure.neutral &&
            m15 == MarketStructure.bearish &&
            dualLevelSweep,
      StrategyCHypothesisId.c3BearishCorrectionContinuation =>
        h4 == MarketStructure.bearish &&
            h1 == MarketStructure.neutral &&
            m15 == MarketStructure.bullish &&
            noSweep,
    };
  }
}
