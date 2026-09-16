import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  const monitor = TriggeredSignalMonitor();

  group('TriggeredSignalMonitor', () {
    test('BUY remains monitoring between SL and TP', () {
      final result = monitor.observe(
        bias: TradingBias.buy,
        stopPrice: 2295,
        targetPrice: 2310,
        candleLow: 2298,
        candleHigh: 2307,
      );

      expect(result.outcome, TriggeredSignalOutcome.monitoring);
      expect(result.isTerminal, isFalse);
    });

    test('BUY detects TP', () {
      final result = monitor.observe(
        bias: TradingBias.buy,
        stopPrice: 2295,
        targetPrice: 2310,
        candleLow: 2300,
        candleHigh: 2310,
      );

      expect(result.outcome, TriggeredSignalOutcome.takeProfitReached);
      expect(result.isTerminal, isTrue);
    });

    test('BUY detects SL', () {
      final result = monitor.observe(
        bias: TradingBias.buy,
        stopPrice: 2295,
        targetPrice: 2310,
        candleLow: 2295,
        candleHigh: 2302,
      );

      expect(result.outcome, TriggeredSignalOutcome.stopLossReached);
    });

    test('SELL detects TP', () {
      final result = monitor.observe(
        bias: TradingBias.sell,
        stopPrice: 2310,
        targetPrice: 2290,
        candleLow: 2290,
        candleHigh: 2305,
      );

      expect(result.outcome, TriggeredSignalOutcome.takeProfitReached);
    });

    test('SELL detects SL', () {
      final result = monitor.observe(
        bias: TradingBias.sell,
        stopPrice: 2310,
        targetPrice: 2290,
        candleLow: 2298,
        candleHigh: 2310,
      );

      expect(result.outcome, TriggeredSignalOutcome.stopLossReached);
    });

    test('same candle touching TP and SL is not guessed', () {
      final result = monitor.observe(
        bias: TradingBias.buy,
        stopPrice: 2295,
        targetPrice: 2310,
        candleLow: 2294,
        candleHigh: 2311,
      );

      expect(result.outcome, TriggeredSignalOutcome.monitoring);
      expect(
        result.reason,
        TriggeredSignalMonitoringReason.ambiguousSameCandleOutcome,
      );
      expect(result.isTerminal, isFalse);
    });

    test('NO TRADE cannot be monitored as triggered signal', () {
      expect(
        () => monitor.observe(
          bias: TradingBias.noTrade,
          stopPrice: 2295,
          targetPrice: 2310,
          candleLow: 2300,
          candleHigh: 2305,
        ),
        throwsArgumentError,
      );
    });
  });
}
