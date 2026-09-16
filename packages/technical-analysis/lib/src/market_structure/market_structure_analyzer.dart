import 'package:market_models/market_models.dart';

import 'market_structure_classifier.dart';
import 'swing_detector.dart';
import 'swing_point.dart';
import 'swing_relationship.dart';

/// Complete deterministic pipeline from closed candles to market structure.
///
/// Only confirmed swings are used. The analyzer deliberately requires the
/// caller to supply an equality tolerance until XAUUSD quote precision is
/// calibrated globally.
final class MarketStructureAnalyzer {
  const MarketStructureAnalyzer({
    this.swingDetector = const SwingDetector(),
    this.relationshipClassifier = const SwingRelationshipClassifier(),
    this.structureClassifier = const MarketStructureClassifier(),
  });

  final SwingDetector swingDetector;
  final SwingRelationshipClassifier relationshipClassifier;
  final MarketStructureClassifier structureClassifier;

  MarketStructureAnalysis analyze(
    List<Candle> closedCandles, {
    required double equalityTolerance,
  }) {
    if (!equalityTolerance.isFinite || equalityTolerance < 0) {
      throw ArgumentError.value(
        equalityTolerance,
        'equalityTolerance',
        'must be finite and non-negative',
      );
    }

    final swings = swingDetector.detect(closedCandles);
    final highs = swings
        .where((swing) => swing.type == SwingType.high)
        .toList();
    final lows = swings.where((swing) => swing.type == SwingType.low).toList();

    SwingRelationship? highRelationship;
    SwingRelationship? lowRelationship;

    if (highs.length >= 2) {
      highRelationship = relationshipClassifier.classify(
        previous: highs[highs.length - 2],
        current: highs.last,
        equalityTolerance: equalityTolerance,
      );
    }

    if (lows.length >= 2) {
      lowRelationship = relationshipClassifier.classify(
        previous: lows[lows.length - 2],
        current: lows.last,
        equalityTolerance: equalityTolerance,
      );
    }

    return MarketStructureAnalysis(
      swings: swings,
      highRelationship: highRelationship,
      lowRelationship: lowRelationship,
      structure: structureClassifier.classify(
        highRelationship: highRelationship,
        lowRelationship: lowRelationship,
      ),
    );
  }
}

final class MarketStructureAnalysis {
  MarketStructureAnalysis({
    required List<SwingPoint> swings,
    required this.highRelationship,
    required this.lowRelationship,
    required this.structure,
  }) : swings = List.unmodifiable(swings);

  final List<SwingPoint> swings;
  final SwingRelationship? highRelationship;
  final SwingRelationship? lowRelationship;
  final MarketStructure structure;
}
