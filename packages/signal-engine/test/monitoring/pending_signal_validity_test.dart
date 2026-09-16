import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = PendingSignalValidityEvaluator();

  group('PendingSignalValidityEvaluator', () {
    test('BUY remains valid while close is not below structural boundary', () {
      final result = evaluator.evaluate(
        bias: TradingBias.buy,
        structuralBoundary: 2295,
        candleClose: 2295,
        waitingCandles: 3,
        maximumWaitingCandles: 5,
      );

      expect(result.state, PendingSignalValidityState.valid);
      expect(result.canStillTrigger, isTrue);
    });

    test('BUY invalidates only after close crosses below structure', () {
      final result = evaluator.evaluate(
        bias: TradingBias.buy,
        structuralBoundary: 2295,
        candleClose: 2294.9,
        waitingCandles: 1,
        maximumWaitingCandles: 5,
      );

      expect(result.state, PendingSignalValidityState.invalidated);
      expect(
        result.reason,
        PendingSignalValidityReason.buyStructureInvalidated,
      );
      expect(result.isTerminal, isTrue);
    });

    test('SELL invalidates only after close crosses above structure', () {
      final result = evaluator.evaluate(
        bias: TradingBias.sell,
        structuralBoundary: 2310,
        candleClose: 2310.1,
        waitingCandles: 1,
        maximumWaitingCandles: 5,
      );

      expect(result.state, PendingSignalValidityState.invalidated);
      expect(
        result.reason,
        PendingSignalValidityReason.sellStructureInvalidated,
      );
    });

    test('exact SELL structural boundary remains valid', () {
      final result = evaluator.evaluate(
        bias: TradingBias.sell,
        structuralBoundary: 2310,
        candleClose: 2310,
        waitingCandles: 4,
        maximumWaitingCandles: 5,
      );

      expect(result.state, PendingSignalValidityState.valid);
    });

    test('expires when explicit waiting-candle budget is reached', () {
      final result = evaluator.evaluate(
        bias: TradingBias.buy,
        structuralBoundary: 2295,
        candleClose: 2300,
        waitingCandles: 5,
        maximumWaitingCandles: 5,
      );

      expect(result.state, PendingSignalValidityState.expired);
      expect(
        result.reason,
        PendingSignalValidityReason.maximumWaitingCandlesReached,
      );
    });

    test('structure invalidation takes priority over expiry', () {
      final result = evaluator.evaluate(
        bias: TradingBias.buy,
        structuralBoundary: 2295,
        candleClose: 2294,
        waitingCandles: 5,
        maximumWaitingCandles: 5,
      );

      expect(result.state, PendingSignalValidityState.invalidated);
    });

    test('rejects NO TRADE bias', () {
      expect(
        () => evaluator.evaluate(
          bias: TradingBias.noTrade,
          structuralBoundary: 2295,
          candleClose: 2300,
          waitingCandles: 0,
          maximumWaitingCandles: 5,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid waiting budget', () {
      expect(
        () => evaluator.evaluate(
          bias: TradingBias.buy,
          structuralBoundary: 2295,
          candleClose: 2300,
          waitingCandles: 0,
          maximumWaitingCandles: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
