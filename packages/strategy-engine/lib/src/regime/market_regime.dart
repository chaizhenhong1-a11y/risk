import 'package:technical_analysis/technical_analysis.dart';

enum MarketRegime {
  trendAligned,
  higherTimeframeTrendLowerTimeframeCorrection,
  range,
  transition,
  unknown,
}

enum MarketRegimeDirection { bullish, bearish, none }

final class MarketRegimeAnalysis {
  const MarketRegimeAnalysis({
    required this.regime,
    required this.direction,
    required this.h4Structure,
    required this.h1Structure,
    required this.rangeEvidencePresent,
  });

  final MarketRegime regime;
  final MarketRegimeDirection direction;
  final MarketStructure h4Structure;
  final MarketStructure h1Structure;

  /// Explicit upstream evidence only. Increment 080 does not invent a range
  /// detector from H4/H1 neutrality alone.
  final bool rangeEvidencePresent;
}
