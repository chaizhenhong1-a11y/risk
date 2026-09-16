import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const planner = StructuralStopPlanner();

  group('StructuralStopPlanner', () {
    test('BUY uses support lower bound as structural invalidation', () {
      final level = _support();
      final result = planner.plan(
        bias: TradingBias.buy,
        entryZoneAnalysis: EntryZoneAnalysis.available(
          EntryZone(
            lowerBound: level.lowerBound,
            upperBound: level.upperBound,
            sourceLevel: level,
          ),
        ),
      );

      expect(result.isAvailable, isTrue);
      expect(result.stop!.price, 2299);
      expect(result.stop!.bias, TradingBias.buy);
      expect(result.stop!.sourceLevel, same(level));
      expect(result.stop!.isInvalidatedBy(2298.99), isTrue);
      expect(result.stop!.isInvalidatedBy(2299), isFalse);
      expect(result.stop!.isInvalidatedBy(2300), isFalse);
    });

    test('SELL uses resistance upper bound as structural invalidation', () {
      final level = _resistance();
      final result = planner.plan(
        bias: TradingBias.sell,
        entryZoneAnalysis: EntryZoneAnalysis.available(
          EntryZone(
            lowerBound: level.lowerBound,
            upperBound: level.upperBound,
            sourceLevel: level,
          ),
        ),
      );

      expect(result.isAvailable, isTrue);
      expect(result.stop!.price, 2307);
      expect(result.stop!.bias, TradingBias.sell);
      expect(result.stop!.isInvalidatedBy(2307.01), isTrue);
      expect(result.stop!.isInvalidatedBy(2307), isFalse);
      expect(result.stop!.isInvalidatedBy(2306), isFalse);
    });

    test('NO TRADE bias cannot receive structural stop', () {
      final level = _support();
      final result = planner.plan(
        bias: TradingBias.noTrade,
        entryZoneAnalysis: EntryZoneAnalysis.available(
          EntryZone(
            lowerBound: level.lowerBound,
            upperBound: level.upperBound,
            sourceLevel: level,
          ),
        ),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        StructuralStopUnavailableReason.noDirectionalBias,
      );
      expect(result.stop, isNull);
    });

    test('missing Entry Zone cannot receive structural stop', () {
      final result = planner.plan(
        bias: TradingBias.buy,
        entryZoneAnalysis: const EntryZoneAnalysis.unavailable(
          EntryZoneUnavailableReason.setupBlocked,
        ),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        StructuralStopUnavailableReason.noEntryZone,
      );
    });

    test('BUY rejects resistance source level', () {
      final level = _resistance();
      final result = planner.plan(
        bias: TradingBias.buy,
        entryZoneAnalysis: EntryZoneAnalysis.available(
          EntryZone(
            lowerBound: level.lowerBound,
            upperBound: level.upperBound,
            sourceLevel: level,
          ),
        ),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        StructuralStopUnavailableReason.mismatchedDirectionalLevel,
      );
    });

    test('SELL rejects support source level', () {
      final level = _support();
      final result = planner.plan(
        bias: TradingBias.sell,
        entryZoneAnalysis: EntryZoneAnalysis.available(
          EntryZone(
            lowerBound: level.lowerBound,
            upperBound: level.upperBound,
            sourceLevel: level,
          ),
        ),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        StructuralStopUnavailableReason.mismatchedDirectionalLevel,
      );
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
