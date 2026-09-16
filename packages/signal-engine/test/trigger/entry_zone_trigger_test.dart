import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const detector = EntryZoneTriggerDetector();

  group('EntryZoneTriggerDetector', () {
    test('BUY triggers when closed candle range intersects Entry Zone', () {
      final result = detector.detect(
        bias: TradingBias.buy,
        entryZoneAnalysis: _availableZone(),
        candleLow: 2299.5,
        candleHigh: 2300.5,
      );

      expect(result.isTriggered, isTrue);
      expect(result.reason, EntryZoneTriggerReason.candleReachedEntryZone);
    });

    test('SELL uses the same market-contact rule', () {
      final result = detector.detect(
        bias: TradingBias.sell,
        entryZoneAnalysis: _availableZone(),
        candleLow: 2301.5,
        candleHigh: 2302.5,
      );

      expect(result.isTriggered, isTrue);
    });

    test('exact boundary touch counts as trigger contact', () {
      final result = detector.detect(
        bias: TradingBias.buy,
        entryZoneAnalysis: _availableZone(),
        candleLow: 2299,
        candleHigh: 2300,
      );

      expect(result.isTriggered, isTrue);
    });

    test('waits while candle remains outside Entry Zone', () {
      final result = detector.detect(
        bias: TradingBias.buy,
        entryZoneAnalysis: _availableZone(),
        candleLow: 2303,
        candleHigh: 2304,
      );

      expect(result.state, EntryZoneTriggerState.waiting);
      expect(result.reason, EntryZoneTriggerReason.candleDidNotReachEntryZone);
    });

    test('NO TRADE is not applicable', () {
      final result = detector.detect(
        bias: TradingBias.noTrade,
        entryZoneAnalysis: _availableZone(),
        candleLow: 2300,
        candleHigh: 2301,
      );

      expect(result.state, EntryZoneTriggerState.notApplicable);
      expect(result.reason, EntryZoneTriggerReason.noDirectionalBias);
    });

    test('missing Entry Zone is not applicable', () {
      final result = detector.detect(
        bias: TradingBias.buy,
        entryZoneAnalysis: const EntryZoneAnalysis.unavailable(
          EntryZoneUnavailableReason.noMatchedPullbackLevel,
        ),
        candleLow: 2300,
        candleHigh: 2301,
      );

      expect(result.state, EntryZoneTriggerState.notApplicable);
      expect(result.reason, EntryZoneTriggerReason.noEntryZone);
    });

    test('rejects inverted candle range', () {
      expect(
        () => detector.detect(
          bias: TradingBias.buy,
          entryZoneAnalysis: _availableZone(),
          candleLow: 2302,
          candleHigh: 2301,
        ),
        throwsArgumentError,
      );
    });
  });
}

EntryZoneAnalysis _availableZone() => EntryZoneAnalysis.available(
  EntryZone(
    lowerBound: 2300,
    upperBound: 2302,
    sourceLevel: KeyLevel(
      type: KeyLevelType.support,
      source: KeyLevelSource.swingLow,
      status: KeyLevelStatus.active,
      lowerBound: 2300,
      upperBound: 2302,
      createdAtCandleIndex: 10,
    ),
  ),
);
