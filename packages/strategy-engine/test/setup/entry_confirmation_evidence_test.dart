import 'package:market_models/market_models.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = EntryConfirmationEvidenceEvaluator();

  group('EntryConfirmationEvidenceEvaluator', () {
    test('BUY recognizes bullish closed M5 candle', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        closedM5Candle: _candle(open: 3250, close: 3252),
      );

      expect(evidence.present, isTrue);
      expect(
        evidence.type,
        EntryConfirmationEvidenceType.directionalM5Confirmation,
      );
    });

    test('SELL recognizes bearish closed M5 candle', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.sell,
        closedM5Candle: _candle(open: 3252, close: 3250),
      );

      expect(evidence.present, isTrue);
    });

    test('BUY does not accept bearish M5 candle as positive evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        closedM5Candle: _candle(open: 3252, close: 3250),
      );

      expect(evidence.present, isFalse);
    });

    test('SELL does not accept bullish M5 candle as positive evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.sell,
        closedM5Candle: _candle(open: 3250, close: 3252),
      );

      expect(evidence.present, isFalse);
    });

    test('doji M5 candle is not directional confirmation', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        closedM5Candle: _candle(open: 3251, close: 3251),
      );

      expect(evidence.present, isFalse);
    });

    test('NO TRADE never receives M5 directional evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.noTrade,
        closedM5Candle: _candle(open: 3250, close: 3252),
      );

      expect(evidence.present, isFalse);
    });
  });
}

Candle _candle({required double open, required double close}) => Candle(
  openTime: DateTime.utc(2026, 9, 15, 10),
  closeTime: DateTime.utc(2026, 9, 15, 10, 5),
  open: open,
  high: 3253,
  low: 3249,
  close: close,
  volume: 100,
);
