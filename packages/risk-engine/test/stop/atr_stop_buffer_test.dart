import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const policy = AtrStopBufferPolicy();
  const protectiveStopPlanner = ProtectiveStopPlanner();

  group('AtrStopBufferMultiplier', () {
    test('requires positive finite value', () {
      expect(() => AtrStopBufferMultiplier(0), throwsArgumentError);
      expect(() => AtrStopBufferMultiplier(-1), throwsArgumentError);
      expect(
        () => AtrStopBufferMultiplier(double.infinity),
        throwsArgumentError,
      );
      expect(() => AtrStopBufferMultiplier(double.nan), throwsArgumentError);
    });
  });

  group('AtrStopBufferPolicy', () {
    test('converts ATR and multiplier into StopBuffer', () {
      final buffer = policy.create(
        atr: 4,
        multiplier: AtrStopBufferMultiplier(0.5),
      );

      expect(buffer.distance, 2);
    });

    test('rejects invalid ATR values', () {
      final multiplier = AtrStopBufferMultiplier(1);

      expect(
        () => policy.create(atr: 0, multiplier: multiplier),
        throwsArgumentError,
      );
      expect(
        () => policy.create(atr: -1, multiplier: multiplier),
        throwsArgumentError,
      );
      expect(
        () => policy.create(atr: double.infinity, multiplier: multiplier),
        throwsArgumentError,
      );
      expect(
        () => policy.create(atr: double.nan, multiplier: multiplier),
        throwsArgumentError,
      );
    });

    test('ATR buffer integrates with BUY protective stop', () {
      final level = _support();
      final buffer = policy.create(
        atr: 4,
        multiplier: AtrStopBufferMultiplier(0.5),
      );

      final result = protectiveStopPlanner.plan(
        structuralStopAnalysis: StructuralStopAnalysis.available(
          StructuralStop(
            price: level.lowerBound,
            bias: TradingBias.buy,
            sourceLevel: level,
          ),
        ),
        buffer: buffer,
      );

      expect(buffer.distance, 2);
      expect(result.isAvailable, isTrue);
      expect(result.stop!.price, 2297);
      expect(result.stop!.structuralBoundary, 2299);
      expect(result.stop!.isOutsideStructure, isTrue);
    });

    test('ATR buffer integrates with SELL protective stop', () {
      final level = _resistance();
      final buffer = policy.create(
        atr: 2.5,
        multiplier: AtrStopBufferMultiplier(0.8),
      );

      final result = protectiveStopPlanner.plan(
        structuralStopAnalysis: StructuralStopAnalysis.available(
          StructuralStop(
            price: level.upperBound,
            bias: TradingBias.sell,
            sourceLevel: level,
          ),
        ),
        buffer: buffer,
      );

      expect(buffer.distance, closeTo(2, 1e-12));
      expect(result.isAvailable, isTrue);
      expect(result.stop!.price, closeTo(2309, 1e-12));
      expect(result.stop!.structuralBoundary, 2307);
      expect(result.stop!.isOutsideStructure, isTrue);
    });
  });
}

KeyLevel _support() => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: 2299,
  upperBound: 2301,
  createdAtCandleIndex: 10,
);

KeyLevel _resistance() => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: 2305,
  upperBound: 2307,
  createdAtCandleIndex: 12,
);
