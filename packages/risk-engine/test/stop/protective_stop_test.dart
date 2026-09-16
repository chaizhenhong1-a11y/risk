import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const planner = ProtectiveStopPlanner();

  group('StopBuffer', () {
    test('requires positive finite distance', () {
      expect(() => StopBuffer(0), throwsArgumentError);
      expect(() => StopBuffer(-0.1), throwsArgumentError);
      expect(() => StopBuffer(double.infinity), throwsArgumentError);
      expect(() => StopBuffer(double.nan), throwsArgumentError);
    });
  });

  group('ProtectiveStopPlanner', () {
    test('BUY places protective stop below structural boundary', () {
      final result = planner.plan(
        structuralStopAnalysis: StructuralStopAnalysis.available(
          StructuralStop(
            price: 2299,
            bias: TradingBias.buy,
            sourceLevel: _support(),
          ),
        ),
        buffer: StopBuffer(1.5),
      );

      expect(result.isAvailable, isTrue);
      expect(result.stop!.price, 2297.5);
      expect(result.stop!.structuralBoundary, 2299);
      expect(result.stop!.bufferDistance, 1.5);
      expect(result.stop!.bias, TradingBias.buy);
      expect(result.stop!.isOutsideStructure, isTrue);
    });

    test('SELL places protective stop above structural boundary', () {
      final result = planner.plan(
        structuralStopAnalysis: StructuralStopAnalysis.available(
          StructuralStop(
            price: 2307,
            bias: TradingBias.sell,
            sourceLevel: _resistance(),
          ),
        ),
        buffer: StopBuffer(2),
      );

      expect(result.isAvailable, isTrue);
      expect(result.stop!.price, 2309);
      expect(result.stop!.structuralBoundary, 2307);
      expect(result.stop!.bufferDistance, 2);
      expect(result.stop!.bias, TradingBias.sell);
      expect(result.stop!.isOutsideStructure, isTrue);
    });

    test('missing structural stop cannot produce protective stop', () {
      final result = planner.plan(
        structuralStopAnalysis: const StructuralStopAnalysis.unavailable(
          StructuralStopUnavailableReason.noEntryZone,
        ),
        buffer: StopBuffer(1),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        ProtectiveStopUnavailableReason.noStructuralStop,
      );
      expect(result.stop, isNull);
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
