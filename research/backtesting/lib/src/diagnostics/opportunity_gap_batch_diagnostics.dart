import 'package:technical_analysis/technical_analysis.dart';

enum GapResearchDirection { continuation, reversal }

final class GapStateDefinition {
  const GapStateDefinition({
    required this.id,
    required this.h4,
    required this.h1,
    required this.m15,
    required this.direction,
  });

  final String id;
  final MarketStructure h4;
  final MarketStructure h1;
  final MarketStructure m15;
  final GapResearchDirection direction;
}

final class GapEpisodeSample {
  const GapEpisodeSample({
    required this.stateId,
    required this.startedAt,
    required this.direction,
    required this.return12,
    required this.return24,
    required this.return48,
  });

  final String stateId;
  final DateTime startedAt;
  final MarketStructure direction;
  final double return12;
  final double return24;
  final double return48;
}

final class GapStateSummary {
  const GapStateSummary({
    required this.stateId,
    required this.samples,
    required this.days,
    required this.bullishSamples,
    required this.bearishSamples,
    required this.rate12,
    required this.rate24,
    required this.rate48,
    required this.firstHalfRate24,
    required this.secondHalfRate24,
  });

  final String stateId;
  final int samples;
  final int days;
  final int bullishSamples;
  final int bearishSamples;
  final double rate12;
  final double rate24;
  final double rate48;
  final double firstHalfRate24;
  final double secondHalfRate24;
}

final class OpportunityGapBatchDiagnostics {
  const OpportunityGapBatchDiagnostics();

  GapStateSummary summarize(String stateId, List<GapEpisodeSample> samples) {
    if (samples.isEmpty) {
      return GapStateSummary(
        stateId: stateId,
        samples: 0,
        days: 0,
        bullishSamples: 0,
        bearishSamples: 0,
        rate12: 0,
        rate24: 0,
        rate48: 0,
        firstHalfRate24: 0,
        secondHalfRate24: 0,
      );
    }

    final ordered = [...samples]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final split = ordered.length ~/ 2;
    final first = ordered.sublist(0, split);
    final second = ordered.sublist(split);

    return GapStateSummary(
      stateId: stateId,
      samples: ordered.length,
      days: ordered
          .map(
            (e) => DateTime.utc(
              e.startedAt.year,
              e.startedAt.month,
              e.startedAt.day,
            ),
          )
          .toSet()
          .length,
      bullishSamples: ordered
          .where((e) => e.direction == MarketStructure.bullish)
          .length,
      bearishSamples: ordered
          .where((e) => e.direction == MarketStructure.bearish)
          .length,
      rate12: _rate(ordered, (e) => e.return12),
      rate24: _rate(ordered, (e) => e.return24),
      rate48: _rate(ordered, (e) => e.return48),
      firstHalfRate24: _rate(first, (e) => e.return24),
      secondHalfRate24: _rate(second, (e) => e.return24),
    );
  }

  double _rate(
    List<GapEpisodeSample> samples,
    double Function(GapEpisodeSample) selector,
  ) {
    if (samples.isEmpty) return 0;
    var matches = 0;
    for (final sample in samples) {
      final value = selector(sample);
      final continuation = sample.direction == MarketStructure.bullish
          ? value > 0
          : value < 0;
      if (continuation) matches++;
    }
    return matches / samples.length;
  }
}
