import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const planner = TargetCandidatePlanner();

  group('TargetCandidatePlanner', () {
    test('BUY chooses nearest active resistance above reference price', () {
      final near = _resistance(2310, 2312, 10);
      final far = _resistance(2320, 2322, 11);

      final result = planner.plan(
        bias: TradingBias.buy,
        referencePrice: 2300,
        keyLevels: [far, near],
      );

      expect(result.isAvailable, isTrue);
      expect(result.target!.price, 2310);
      expect(result.target!.sourceLevel, same(near));
    });

    test('SELL chooses nearest active support below reference price', () {
      final near = _support(2290, 2292, 10);
      final far = _support(2280, 2282, 11);

      final result = planner.plan(
        bias: TradingBias.sell,
        referencePrice: 2300,
        keyLevels: [far, near],
      );

      expect(result.isAvailable, isTrue);
      expect(result.target!.price, 2292);
      expect(result.target!.sourceLevel, same(near));
    });

    test('ignores same-direction level type and levels behind price', () {
      final result = planner.plan(
        bias: TradingBias.buy,
        referencePrice: 2300,
        keyLevels: [
          _support(2290, 2292, 1),
          _resistance(2295, 2297, 2),
          _resistance(2310, 2312, 3),
        ],
      );

      expect(result.isAvailable, isTrue);
      expect(result.target!.price, 2310);
    });

    test('ignores broken opposing levels', () {
      final result = planner.plan(
        bias: TradingBias.buy,
        referencePrice: 2300,
        keyLevels: [
          KeyLevel(
            type: KeyLevelType.resistance,
            source: KeyLevelSource.swingHigh,
            status: KeyLevelStatus.broken,
            lowerBound: 2305,
            upperBound: 2307,
            createdAtCandleIndex: 1,
          ),
          _resistance(2310, 2312, 2),
        ],
      );

      expect(result.target!.price, 2310);
    });

    test('newer level wins exact target-price tie', () {
      final oldLevel = _resistance(2310, 2312, 5);
      final newLevel = _resistance(2310, 2311, 9);

      final result = planner.plan(
        bias: TradingBias.buy,
        referencePrice: 2300,
        keyLevels: [oldLevel, newLevel],
      );

      expect(result.target!.sourceLevel, same(newLevel));
    });

    test('returns unavailable when no opposing active level is ahead', () {
      final result = planner.plan(
        bias: TradingBias.sell,
        referencePrice: 2300,
        keyLevels: [_resistance(2310, 2312, 1), _support(2305, 2307, 2)],
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        TargetCandidateUnavailableReason.noOpposingActiveLevelAhead,
      );
      expect(result.target, isNull);
    });

    test('NO TRADE cannot produce target', () {
      final result = planner.plan(
        bias: TradingBias.noTrade,
        referencePrice: 2300,
        keyLevels: [_resistance(2310, 2312, 1)],
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        TargetCandidateUnavailableReason.noDirectionalBias,
      );
    });

    test('rejects non-finite reference price', () {
      expect(
        () => planner.plan(
          bias: TradingBias.buy,
          referencePrice: double.nan,
          keyLevels: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}

KeyLevel _support(double lower, double upper, int index) => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);

KeyLevel _resistance(double lower, double upper, int index) => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);
