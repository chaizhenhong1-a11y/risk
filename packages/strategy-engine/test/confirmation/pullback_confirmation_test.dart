import 'package:market_models/market_models.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = PullbackConfirmationAnalyzer();

  group('PullbackConfirmationAnalyzer', () {
    test('BUY confirms after bullish close back above support zone', () {
      final level = _support();
      final result = analyzer.analyze(
        bias: TradingBias.buy,
        pullback: _inZone(level),
        closedCandle: _candle(
          open: 3249.5,
          low: 3248.5,
          high: 3253,
          close: 3252,
        ),
      );

      expect(result.state, PullbackConfirmationState.confirmed);
      expect(
        result.reason,
        PullbackConfirmationReason.bullishRejectionConfirmed,
      );
      expect(result.isConfirmed, isTrue);
    });

    test('BUY waits if bullish candle still closes inside support zone', () {
      final result = analyzer.analyze(
        bias: TradingBias.buy,
        pullback: _inZone(_support()),
        closedCandle: _candle(
          open: 3249.5,
          low: 3248.5,
          high: 3251,
          close: 3250.5,
        ),
      );

      expect(result.state, PullbackConfirmationState.waiting);
      expect(
        result.reason,
        PullbackConfirmationReason.waitingForBullishRejection,
      );
    });

    test('BUY waits if close above support is bearish', () {
      final result = analyzer.analyze(
        bias: TradingBias.buy,
        pullback: _inZone(_support()),
        closedCandle: _candle(open: 3253, low: 3249, high: 3254, close: 3252),
      );

      expect(result.state, PullbackConfirmationState.waiting);
    });

    test('SELL confirms after bearish close back below resistance zone', () {
      final level = _resistance();
      final result = analyzer.analyze(
        bias: TradingBias.sell,
        pullback: _inZone(level),
        closedCandle: _candle(
          open: 3300.5,
          low: 3297,
          high: 3301.5,
          close: 3298,
        ),
      );

      expect(result.state, PullbackConfirmationState.confirmed);
      expect(
        result.reason,
        PullbackConfirmationReason.bearishRejectionConfirmed,
      );
    });

    test(
      'SELL waits if bearish candle still closes inside resistance zone',
      () {
        final result = analyzer.analyze(
          bias: TradingBias.sell,
          pullback: _inZone(_resistance()),
          closedCandle: _candle(
            open: 3300.5,
            low: 3299.5,
            high: 3301.5,
            close: 3300,
          ),
        );

        expect(result.state, PullbackConfirmationState.waiting);
        expect(
          result.reason,
          PullbackConfirmationReason.waitingForBearishRejection,
        );
      },
    );

    test('SELL waits if close below resistance is bullish', () {
      final result = analyzer.analyze(
        bias: TradingBias.sell,
        pullback: _inZone(_resistance()),
        closedCandle: _candle(open: 3297, low: 3296, high: 3300, close: 3298),
      );

      expect(result.state, PullbackConfirmationState.waiting);
    });

    test('waits when pullback is not currently in zone', () {
      final result = analyzer.analyze(
        bias: TradingBias.buy,
        pullback: const PullbackAnalysis(
          state: PullbackState.waiting,
          reason: PullbackReason.priceNotAtDirectionalLevel,
        ),
        closedCandle: _candle(open: 3255, low: 3254, high: 3257, close: 3256),
      );

      expect(result.state, PullbackConfirmationState.waiting);
      expect(result.reason, PullbackConfirmationReason.pullbackNotInZone);
    });

    test('NO TRADE bias makes confirmation not applicable', () {
      final result = analyzer.analyze(
        bias: TradingBias.noTrade,
        pullback: _inZone(_support()),
        closedCandle: _candle(open: 3249, low: 3248, high: 3253, close: 3252),
      );

      expect(result.state, PullbackConfirmationState.notApplicable);
      expect(result.reason, PullbackConfirmationReason.noTradeBias);
    });

    test('exact support upper-bound close is not enough confirmation', () {
      final result = analyzer.analyze(
        bias: TradingBias.buy,
        pullback: _inZone(_support()),
        closedCandle: _candle(open: 3249, low: 3248, high: 3252, close: 3251),
      );

      expect(result.state, PullbackConfirmationState.waiting);
    });

    test('exact resistance lower-bound close is not enough confirmation', () {
      final result = analyzer.analyze(
        bias: TradingBias.sell,
        pullback: _inZone(_resistance()),
        closedCandle: _candle(open: 3301, low: 3298, high: 3302, close: 3299),
      );

      expect(result.state, PullbackConfirmationState.waiting);
    });
  });
}

PullbackAnalysis _inZone(KeyLevel level) => PullbackAnalysis(
  state: PullbackState.inZone,
  reason: level.type == KeyLevelType.support
      ? PullbackReason.priceAtSupport
      : PullbackReason.priceAtResistance,
  matchedLevel: level,
);

KeyLevel _support() => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: 3249,
  upperBound: 3251,
  createdAtCandleIndex: 10,
);

KeyLevel _resistance() => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: 3299,
  upperBound: 3301,
  createdAtCandleIndex: 20,
);

Candle _candle({
  required double open,
  required double low,
  required double high,
  required double close,
}) {
  final openTime = DateTime.utc(2026, 9, 15);
  return Candle(
    openTime: openTime,
    closeTime: openTime.add(const Duration(minutes: 15)),
    open: open,
    high: high,
    low: low,
    close: close,
    volume: 100,
  );
}
