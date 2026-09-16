import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = MarketStructureAnalyzer();

  group('MarketStructureAnalyzer', () {
    test('derives bullish structure from confirmed HH and HL swings', () {
      final result = analyzer.analyze(
        _candles(
          highs: [10, 12, 15, 12, 10, 13, 16, 13, 11, 12, 13],
          lows: [8, 9, 10, 8, 5, 9, 11, 9, 7, 9, 10],
        ),
        equalityTolerance: 0,
      );

      expect(result.highRelationship, SwingRelationship.higherHigh);
      expect(result.lowRelationship, SwingRelationship.higherLow);
      expect(result.structure, MarketStructure.bullish);
    });

    test('derives bearish structure from confirmed LH and LL swings', () {
      final result = analyzer.analyze(
        _candles(
          highs: [12, 14, 16, 13, 11, 12, 14, 11, 9, 10, 11],
          lows: [9, 10, 11, 9, 6, 8, 9, 7, 4, 6, 7],
        ),
        equalityTolerance: 0,
      );

      expect(result.highRelationship, SwingRelationship.lowerHigh);
      expect(result.lowRelationship, SwingRelationship.lowerLow);
      expect(result.structure, MarketStructure.bearish);
    });

    test('returns unknown when confirmed swing history is insufficient', () {
      final result = analyzer.analyze(
        _candles(highs: [10, 12, 15, 13, 11], lows: [8, 9, 10, 9, 8]),
        equalityTolerance: 0,
      );

      expect(result.structure, MarketStructure.unknown);
    });

    test(
      'uses equality tolerance for the integrated relationship pipeline',
      () {
        final result = analyzer.analyze(
          _candles(
            highs: [10, 12, 15, 12, 10, 13, 15.4, 13, 11, 12, 13],
            lows: [8, 9, 10, 8, 5, 9, 11, 9, 7, 9, 10],
          ),
          equalityTolerance: 0.5,
        );

        expect(result.highRelationship, SwingRelationship.equalHigh);
        expect(result.lowRelationship, SwingRelationship.higherLow);
        expect(result.structure, MarketStructure.neutral);
      },
    );

    test('rejects invalid equality tolerance before analysis', () {
      expect(
        () => analyzer.analyze(
          _candles(highs: [10, 12, 15, 13, 11], lows: [8, 9, 10, 9, 8]),
          equalityTolerance: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}

List<Candle> _candles({required List<num> highs, required List<num> lows}) {
  assert(highs.length == lows.length);

  return List.generate(highs.length, (index) {
    final high = highs[index].toDouble();
    final low = lows[index].toDouble();
    final midpoint = (high + low) / 2;
    final openTime = DateTime.utc(2026, 9, 15).add(Duration(hours: index));

    return Candle(
      openTime: openTime,
      closeTime: openTime.add(const Duration(hours: 1)),
      open: midpoint,
      high: high,
      low: low,
      close: midpoint,
      volume: 100,
    );
  });
}
