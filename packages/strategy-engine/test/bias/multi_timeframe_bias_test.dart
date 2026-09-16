import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = MultiTimeframeBiasAnalyzer();

  group('MultiTimeframeBiasAnalyzer', () {
    test('H4 bullish + H1 bullish produces BUY bias', () {
      final result = analyzer.analyze(
        h4Structure: MarketStructure.bullish,
        h1Structure: MarketStructure.bullish,
      );

      expect(result.bias, TradingBias.buy);
      expect(result.reason, TradingBiasReason.h4H1BullishAlignment);
      expect(result.canLookForBuy, isTrue);
      expect(result.canLookForSell, isFalse);
      expect(result.shouldStandAside, isFalse);
    });

    test('H4 bearish + H1 bearish produces SELL bias', () {
      final result = analyzer.analyze(
        h4Structure: MarketStructure.bearish,
        h1Structure: MarketStructure.bearish,
      );

      expect(result.bias, TradingBias.sell);
      expect(result.reason, TradingBiasReason.h4H1BearishAlignment);
      expect(result.canLookForSell, isTrue);
      expect(result.canLookForBuy, isFalse);
      expect(result.shouldStandAside, isFalse);
    });

    test('bullish/bearish conflict produces NO TRADE', () {
      final result = analyzer.analyze(
        h4Structure: MarketStructure.bullish,
        h1Structure: MarketStructure.bearish,
      );

      expect(result.bias, TradingBias.noTrade);
      expect(result.reason, TradingBiasReason.higherTimeframeConflict);
      expect(result.shouldStandAside, isTrue);
    });

    test('bearish/bullish conflict produces NO TRADE', () {
      final result = analyzer.analyze(
        h4Structure: MarketStructure.bearish,
        h1Structure: MarketStructure.bullish,
      );

      expect(result.bias, TradingBias.noTrade);
      expect(result.reason, TradingBiasReason.higherTimeframeConflict);
    });

    test('neutral on either trading timeframe produces NO TRADE', () {
      for (final pair in [
        (MarketStructure.neutral, MarketStructure.bullish),
        (MarketStructure.bearish, MarketStructure.neutral),
        (MarketStructure.neutral, MarketStructure.neutral),
      ]) {
        final result = analyzer.analyze(
          h4Structure: pair.$1,
          h1Structure: pair.$2,
        );

        expect(result.bias, TradingBias.noTrade);
        expect(result.reason, TradingBiasReason.higherTimeframeNeutral);
      }
    });

    test('unknown on either trading timeframe produces NO TRADE', () {
      for (final pair in [
        (MarketStructure.unknown, MarketStructure.bullish),
        (MarketStructure.bearish, MarketStructure.unknown),
        (MarketStructure.unknown, MarketStructure.unknown),
      ]) {
        final result = analyzer.analyze(
          h4Structure: pair.$1,
          h1Structure: pair.$2,
        );

        expect(result.bias, TradingBias.noTrade);
        expect(result.reason, TradingBiasReason.higherTimeframeUnknown);
      }
    });

    test('D1 is retained as context but does not gate BUY bias', () {
      final result = analyzer.analyze(
        d1Context: MarketStructure.bearish,
        h4Structure: MarketStructure.bullish,
        h1Structure: MarketStructure.bullish,
      );

      expect(result.d1Context, MarketStructure.bearish);
      expect(result.bias, TradingBias.buy);
    });

    test('D1 is retained as context but does not gate SELL bias', () {
      final result = analyzer.analyze(
        d1Context: MarketStructure.bullish,
        h4Structure: MarketStructure.bearish,
        h1Structure: MarketStructure.bearish,
      );

      expect(result.d1Context, MarketStructure.bullish);
      expect(result.bias, TradingBias.sell);
    });
  });
}
