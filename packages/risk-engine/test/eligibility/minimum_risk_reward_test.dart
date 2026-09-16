import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  const calculator = RiskRewardCalculator();
  const gate = MinimumRiskRewardGate();

  group('MinimumRiskRewardPolicy', () {
    test('requires a positive finite threshold', () {
      expect(() => MinimumRiskRewardPolicy(0), throwsArgumentError);
      expect(() => MinimumRiskRewardPolicy(-1), throwsArgumentError);
      expect(
        () => MinimumRiskRewardPolicy(double.infinity),
        throwsArgumentError,
      );
      expect(() => MinimumRiskRewardPolicy(double.nan), throwsArgumentError);
    });
  });

  group('MinimumRiskRewardGate', () {
    test('passes when actual RR is above configured minimum', () {
      final analysis = calculator.calculate(
        bias: TradingBias.buy,
        entryPrice: 2300,
        stopPrice: 2295,
        targetPrice: 2312,
      );

      final result = gate.evaluate(
        analysis: analysis,
        policy: MinimumRiskRewardPolicy(2),
      );

      expect(result.isPassed, isTrue);
      expect(result.actualRatio, 2.4);
      expect(result.minimumRatio, 2);
      expect(result.blockReason, isNull);
    });

    test('passes when actual RR equals configured minimum', () {
      final analysis = calculator.calculate(
        bias: TradingBias.buy,
        entryPrice: 2300,
        stopPrice: 2295,
        targetPrice: 2310,
      );

      final result = gate.evaluate(
        analysis: analysis,
        policy: MinimumRiskRewardPolicy(2),
      );

      expect(result.isPassed, isTrue);
      expect(result.actualRatio, 2);
    });

    test('blocks when actual RR is below configured minimum', () {
      final analysis = calculator.calculate(
        bias: TradingBias.sell,
        entryPrice: 2300,
        stopPrice: 2305,
        targetPrice: 2292,
      );

      final result = gate.evaluate(
        analysis: analysis,
        policy: MinimumRiskRewardPolicy(2),
      );

      expect(result.isPassed, isFalse);
      expect(result.actualRatio, 1.6);
      expect(
        result.blockReason,
        MinimumRiskRewardBlockReason.belowMinimumRatio,
      );
    });

    test('same RR can pass or fail under different research policies', () {
      final analysis = calculator.calculate(
        bias: TradingBias.buy,
        entryPrice: 2300,
        stopPrice: 2295,
        targetPrice: 2309,
      );

      final loose = gate.evaluate(
        analysis: analysis,
        policy: MinimumRiskRewardPolicy(1.5),
      );
      final strict = gate.evaluate(
        analysis: analysis,
        policy: MinimumRiskRewardPolicy(2),
      );

      expect(analysis.riskReward!.ratio, 1.8);
      expect(loose.isPassed, isTrue);
      expect(strict.isPassed, isFalse);
    });

    test('blocks invalid RR analysis before threshold comparison', () {
      final invalid = calculator.calculate(
        bias: TradingBias.buy,
        entryPrice: 2300,
        stopPrice: 2301,
        targetPrice: 2310,
      );

      final result = gate.evaluate(
        analysis: invalid,
        policy: MinimumRiskRewardPolicy(2),
      );

      expect(result.isPassed, isFalse);
      expect(result.actualRatio, isNull);
      expect(
        result.blockReason,
        MinimumRiskRewardBlockReason.invalidRiskReward,
      );
    });

    test('NO TRADE RR analysis is blocked as invalid risk geometry', () {
      final invalid = calculator.calculate(
        bias: TradingBias.noTrade,
        entryPrice: 2300,
        stopPrice: 2295,
        targetPrice: 2310,
      );

      final result = gate.evaluate(
        analysis: invalid,
        policy: MinimumRiskRewardPolicy(1.5),
      );

      expect(result.isPassed, isFalse);
      expect(
        result.blockReason,
        MinimumRiskRewardBlockReason.invalidRiskReward,
      );
    });
  });
}
