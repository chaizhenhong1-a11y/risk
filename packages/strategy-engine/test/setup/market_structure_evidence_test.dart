import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = MarketStructureEvidenceEvaluator();

  group('MarketStructureEvidenceEvaluator', () {
    test('BUY recognizes bullish M15 structure', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        m15Structure: MarketStructure.bullish,
      );

      expect(evidence.present, isTrue);
      expect(
        evidence.type,
        MarketStructureEvidenceType.directionalM15Structure,
      );
    });

    test('SELL recognizes bearish M15 structure', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.sell,
        m15Structure: MarketStructure.bearish,
      );

      expect(evidence.present, isTrue);
    });

    test('BUY does not treat bearish M15 structure as positive evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        m15Structure: MarketStructure.bearish,
      );

      expect(evidence.present, isFalse);
    });

    test('SELL does not treat bullish M15 structure as positive evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.sell,
        m15Structure: MarketStructure.bullish,
      );

      expect(evidence.present, isFalse);
    });

    test('neutral M15 structure is simply missing evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        m15Structure: MarketStructure.neutral,
      );

      expect(evidence.present, isFalse);
    });

    test('unknown M15 structure is simply missing evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.sell,
        m15Structure: MarketStructure.unknown,
      );

      expect(evidence.present, isFalse);
    });

    test('NO TRADE never receives directional M15 evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.noTrade,
        m15Structure: MarketStructure.bullish,
      );

      expect(evidence.present, isFalse);
    });
  });
}
