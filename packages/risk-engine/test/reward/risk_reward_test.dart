import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  const calculator = RiskRewardCalculator();

  group('RiskRewardCalculator', () {
    test('calculates BUY risk, reward and ratio', () {
      final result = calculator.calculate(
        bias: TradingBias.buy,
        entryPrice: 2300,
        stopPrice: 2295,
        targetPrice: 2310,
      );

      expect(result.isValid, isTrue);
      expect(result.riskReward!.riskDistance, 5);
      expect(result.riskReward!.rewardDistance, 10);
      expect(result.riskReward!.ratio, 2);
    });

    test('calculates SELL risk, reward and ratio', () {
      final result = calculator.calculate(
        bias: TradingBias.sell,
        entryPrice: 2300,
        stopPrice: 2304,
        targetPrice: 2290,
      );

      expect(result.isValid, isTrue);
      expect(result.riskReward!.riskDistance, 4);
      expect(result.riskReward!.rewardDistance, 10);
      expect(result.riskReward!.ratio, 2.5);
    });

    test('preserves non-integer RR precision', () {
      final result = calculator.calculate(
        bias: TradingBias.buy,
        entryPrice: 2300,
        stopPrice: 2297,
        targetPrice: 2305,
      );

      expect(result.riskReward!.ratio, closeTo(5 / 3, 1e-12));
    });

    test('rejects BUY stop at or above entry', () {
      for (final stop in [2300.0, 2301.0]) {
        final result = calculator.calculate(
          bias: TradingBias.buy,
          entryPrice: 2300,
          stopPrice: stop,
          targetPrice: 2310,
        );

        expect(result.isValid, isFalse);
        expect(result.invalidReason, RiskRewardInvalidReason.invalidBuyStop);
      }
    });

    test('rejects BUY target at or below entry', () {
      for (final target in [2300.0, 2299.0]) {
        final result = calculator.calculate(
          bias: TradingBias.buy,
          entryPrice: 2300,
          stopPrice: 2295,
          targetPrice: target,
        );

        expect(result.isValid, isFalse);
        expect(result.invalidReason, RiskRewardInvalidReason.invalidBuyTarget);
      }
    });

    test('rejects SELL stop at or below entry', () {
      for (final stop in [2300.0, 2299.0]) {
        final result = calculator.calculate(
          bias: TradingBias.sell,
          entryPrice: 2300,
          stopPrice: stop,
          targetPrice: 2290,
        );

        expect(result.isValid, isFalse);
        expect(result.invalidReason, RiskRewardInvalidReason.invalidSellStop);
      }
    });

    test('rejects SELL target at or above entry', () {
      for (final target in [2300.0, 2301.0]) {
        final result = calculator.calculate(
          bias: TradingBias.sell,
          entryPrice: 2300,
          stopPrice: 2305,
          targetPrice: target,
        );

        expect(result.isValid, isFalse);
        expect(result.invalidReason, RiskRewardInvalidReason.invalidSellTarget);
      }
    });

    test('NO TRADE cannot produce RR', () {
      final result = calculator.calculate(
        bias: TradingBias.noTrade,
        entryPrice: 2300,
        stopPrice: 2295,
        targetPrice: 2310,
      );

      expect(result.isValid, isFalse);
      expect(result.invalidReason, RiskRewardInvalidReason.noDirectionalBias);
    });

    test('rejects non-finite prices', () {
      expect(
        () => calculator.calculate(
          bias: TradingBias.buy,
          entryPrice: double.nan,
          stopPrice: 2295,
          targetPrice: 2310,
        ),
        throwsArgumentError,
      );

      expect(
        () => calculator.calculate(
          bias: TradingBias.buy,
          entryPrice: 2300,
          stopPrice: double.infinity,
          targetPrice: 2310,
        ),
        throwsArgumentError,
      );

      expect(
        () => calculator.calculate(
          bias: TradingBias.buy,
          entryPrice: 2300,
          stopPrice: 2295,
          targetPrice: double.negativeInfinity,
        ),
        throwsArgumentError,
      );
    });
  });
}
