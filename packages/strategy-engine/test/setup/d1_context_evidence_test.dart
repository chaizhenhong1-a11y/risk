import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = D1ContextEvidenceEvaluator();

  group('D1ContextEvidenceEvaluator', () {
    test('BUY plus bullish D1 is aligned', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        d1Structure: MarketStructure.bullish,
      );

      expect(evidence.alignment, D1ContextAlignment.aligned);
      expect(evidence.present, isTrue);
    });

    test('SELL plus bearish D1 is aligned', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.sell,
        d1Structure: MarketStructure.bearish,
      );

      expect(evidence.alignment, D1ContextAlignment.aligned);
      expect(evidence.present, isTrue);
    });

    test('BUY plus bearish D1 is opposed, not blocked', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        d1Structure: MarketStructure.bearish,
      );

      expect(evidence.alignment, D1ContextAlignment.opposed);
      expect(evidence.present, isFalse);
    });

    test('SELL plus bullish D1 is opposed', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.sell,
        d1Structure: MarketStructure.bullish,
      );

      expect(evidence.alignment, D1ContextAlignment.opposed);
      expect(evidence.present, isFalse);
    });

    test('neutral D1 remains explicit context', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        d1Structure: MarketStructure.neutral,
      );

      expect(evidence.alignment, D1ContextAlignment.neutral);
      expect(evidence.present, isFalse);
    });

    test('unknown D1 is unavailable', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.sell,
        d1Structure: MarketStructure.unknown,
      );

      expect(evidence.alignment, D1ContextAlignment.unavailable);
      expect(evidence.present, isFalse);
    });

    test('NO TRADE has no directional D1 evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.noTrade,
        d1Structure: MarketStructure.bullish,
      );

      expect(evidence.alignment, D1ContextAlignment.unavailable);
      expect(evidence.present, isFalse);
    });
  });
}
