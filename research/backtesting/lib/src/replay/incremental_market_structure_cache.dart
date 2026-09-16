import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';

/// Replay-local incremental equivalent of [MarketStructureAnalyzer].
///
/// Historical replay exposes an ever-growing prefix of the same candle series.
/// Re-running the full swing scan on every newly closed M15/H1/H4 candle makes
/// a long replay quadratic. This cache evaluates only pivots that have just
/// become confirmable while retaining every previously confirmed swing.
///
/// It preserves the frozen 2-left / 2-right confirmation contract and falls
/// back to a clean rebuild if the supplied history ever shrinks.
final class IncrementalMarketStructureCache {
  IncrementalMarketStructureCache({
    this.pivotLeft = 2,
    this.pivotRight = 2,
    this.relationshipClassifier = const SwingRelationshipClassifier(),
    this.structureClassifier = const MarketStructureClassifier(),
  }) : assert(pivotLeft > 0),
       assert(pivotRight > 0);

  final int pivotLeft;
  final int pivotRight;
  final SwingRelationshipClassifier relationshipClassifier;
  final MarketStructureClassifier structureClassifier;

  int _processedHistoryLength = 0;
  final List<SwingPoint> _swings = [];
  final List<SwingPoint> _highs = [];
  final List<SwingPoint> _lows = [];

  MarketStructureAnalysis update(
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

    if (closedCandles.length < _processedHistoryLength) {
      _reset();
    }

    final firstCandidate = _processedHistoryLength == 0
        ? pivotLeft
        : (_processedHistoryLength - pivotRight).clamp(
            pivotLeft,
            closedCandles.length,
          );
    final lastCandidate = closedCandles.length - pivotRight - 1;

    if (lastCandidate >= firstCandidate) {
      for (var index = firstCandidate; index <= lastCandidate; index++) {
        final candidate = closedCandles[index];
        if (_isSwingHigh(closedCandles, index, candidate.high)) {
          final swing = SwingPoint(
            type: SwingType.high,
            candleIndex: index,
            price: candidate.high,
          );
          _swings.add(swing);
          _highs.add(swing);
        }
        if (_isSwingLow(closedCandles, index, candidate.low)) {
          final swing = SwingPoint(
            type: SwingType.low,
            candleIndex: index,
            price: candidate.low,
          );
          _swings.add(swing);
          _lows.add(swing);
        }
      }
    }

    _processedHistoryLength = closedCandles.length;

    final highRelationship = _relationshipFor(
      _highs,
      equalityTolerance: equalityTolerance,
    );
    final lowRelationship = _relationshipFor(
      _lows,
      equalityTolerance: equalityTolerance,
    );

    return MarketStructureAnalysis(
      swings: _swings,
      highRelationship: highRelationship,
      lowRelationship: lowRelationship,
      structure: structureClassifier.classify(
        highRelationship: highRelationship,
        lowRelationship: lowRelationship,
      ),
    );
  }

  SwingRelationship? _relationshipFor(
    List<SwingPoint> swings, {
    required double equalityTolerance,
  }) {
    if (swings.length < 2) {
      return null;
    }
    return relationshipClassifier.classify(
      previous: swings[swings.length - 2],
      current: swings.last,
      equalityTolerance: equalityTolerance,
    );
  }

  bool _isSwingHigh(List<Candle> candles, int index, double candidateHigh) {
    for (var offset = 1; offset <= pivotLeft; offset++) {
      if (candidateHigh <= candles[index - offset].high) return false;
    }
    for (var offset = 1; offset <= pivotRight; offset++) {
      if (candidateHigh <= candles[index + offset].high) return false;
    }
    return true;
  }

  bool _isSwingLow(List<Candle> candles, int index, double candidateLow) {
    for (var offset = 1; offset <= pivotLeft; offset++) {
      if (candidateLow >= candles[index - offset].low) return false;
    }
    for (var offset = 1; offset <= pivotRight; offset++) {
      if (candidateLow >= candles[index + offset].low) return false;
    }
    return true;
  }

  void _reset() {
    _processedHistoryLength = 0;
    _swings.clear();
    _highs.clear();
    _lows.clear();
  }
}
