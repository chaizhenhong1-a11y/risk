import 'package:market_models/market_models.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const detector = PullbackDetector();

  group('PullbackDetector', () {
    test('BUY bias touching active support is a pullback', () {
      final support = _support(3249, 3251, index: 10);

      final result = detector.analyze(
        bias: TradingBias.buy,
        closedCandle: _candle(low: 3250, high: 3255, close: 3253),
        keyLevels: [support],
      );

      expect(result.state, PullbackState.inZone);
      expect(result.reason, PullbackReason.priceAtSupport);
      expect(result.matchedLevel, same(support));
      expect(result.hasPullback, isTrue);
    });

    test('SELL bias touching active resistance is a pullback', () {
      final resistance = _resistance(3299, 3301, index: 20);

      final result = detector.analyze(
        bias: TradingBias.sell,
        closedCandle: _candle(low: 3295, high: 3300, close: 3297),
        keyLevels: [resistance],
      );

      expect(result.state, PullbackState.inZone);
      expect(result.reason, PullbackReason.priceAtResistance);
      expect(result.matchedLevel, same(resistance));
    });

    test('BUY bias ignores resistance', () {
      final result = detector.analyze(
        bias: TradingBias.buy,
        closedCandle: _candle(low: 3299, high: 3301, close: 3300),
        keyLevels: [_resistance(3299, 3301, index: 20)],
      );

      expect(result.state, PullbackState.waiting);
      expect(result.reason, PullbackReason.noActiveDirectionalLevel);
      expect(result.matchedLevel, isNull);
    });

    test('SELL bias ignores support', () {
      final result = detector.analyze(
        bias: TradingBias.sell,
        closedCandle: _candle(low: 3249, high: 3251, close: 3250),
        keyLevels: [_support(3249, 3251, index: 10)],
      );

      expect(result.state, PullbackState.waiting);
      expect(result.reason, PullbackReason.noActiveDirectionalLevel);
    });

    test('inactive directional level cannot qualify as pullback', () {
      final result = detector.analyze(
        bias: TradingBias.buy,
        closedCandle: _candle(low: 3249, high: 3251, close: 3250),
        keyLevels: [
          _support(3249, 3251, index: 10, status: KeyLevelStatus.broken),
        ],
      );

      expect(result.state, PullbackState.waiting);
      expect(result.reason, PullbackReason.noActiveDirectionalLevel);
    });

    test('directional level exists but price has not reached it', () {
      final result = detector.analyze(
        bias: TradingBias.buy,
        closedCandle: _candle(low: 3260, high: 3265, close: 3263),
        keyLevels: [_support(3249, 3251, index: 10)],
      );

      expect(result.state, PullbackState.waiting);
      expect(result.reason, PullbackReason.priceNotAtDirectionalLevel);
      expect(result.hasPullback, isFalse);
    });

    test('NO TRADE bias makes pullback analysis not applicable', () {
      final result = detector.analyze(
        bias: TradingBias.noTrade,
        closedCandle: _candle(low: 3249, high: 3251, close: 3250),
        keyLevels: [_support(3249, 3251, index: 10)],
      );

      expect(result.state, PullbackState.notApplicable);
      expect(result.reason, PullbackReason.noTradeBias);
      expect(result.matchedLevel, isNull);
    });

    test('boundary contact counts as entering the pullback zone', () {
      final support = _support(3249, 3251, index: 10);

      final result = detector.analyze(
        bias: TradingBias.buy,
        closedCandle: _candle(low: 3251, high: 3255, close: 3254),
        keyLevels: [support],
      );

      expect(result.state, PullbackState.inZone);
      expect(result.matchedLevel, same(support));
    });

    test(
      'when multiple levels are touched, chooses nearest midpoint to close',
      () {
        final farther = _support(3248, 3252, index: 10);
        final nearer = _support(3252, 3254, index: 20);

        final result = detector.analyze(
          bias: TradingBias.buy,
          closedCandle: _candle(low: 3250, high: 3254, close: 3253.2),
          keyLevels: [farther, nearer],
        );

        expect(result.matchedLevel, same(nearer));
      },
    );

    test('equal distance tie prefers the newer level', () {
      final older = _support(3249, 3251, index: 10);
      final newer = _support(3251, 3253, index: 20);

      final result = detector.analyze(
        bias: TradingBias.buy,
        closedCandle: _candle(low: 3250, high: 3252, close: 3251),
        keyLevels: [older, newer],
      );

      expect(result.matchedLevel, same(newer));
    });
  });
}

KeyLevel _support(
  double lower,
  double upper, {
  required int index,
  KeyLevelStatus status = KeyLevelStatus.active,
}) => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: status,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);

KeyLevel _resistance(
  double lower,
  double upper, {
  required int index,
  KeyLevelStatus status = KeyLevelStatus.active,
}) => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: status,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);

Candle _candle({
  required double low,
  required double high,
  required double close,
}) {
  final openTime = DateTime.utc(2026, 9, 15);
  return Candle(
    openTime: openTime,
    closeTime: openTime.add(const Duration(minutes: 15)),
    open: (low + high) / 2,
    high: high,
    low: low,
    close: close,
    volume: 100,
  );
}
