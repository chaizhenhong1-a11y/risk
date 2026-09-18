import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_candle.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_trade_lifecycle.dart';

void main() {
  PaperSignal signal(PaperSignalSide side) => PaperSignal(
    id: 'id',
    symbol: 'XAUUSD',
    strategy: 'A',
    side: side,
    observedAt: DateTime.utc(2026, 9, 17, 8),
    entry: 3600,
    stopLoss: side == PaperSignalSide.buy ? 3590 : 3610,
    takeProfit: side == PaperSignalSide.buy ? 3620 : 3580,
    rewardRisk: 2,
    reason: 'test',
  );

  PaperCandle candle({required double high, required double low}) =>
      PaperCandle(
        closeTime: DateTime.utc(2026, 9, 17, 8, 5),
        open: 3600,
        high: high,
        low: low,
        close: 3600,
      );

  test('BUY target resolves to positive R', () {
    final result = const PaperTradeLifecycle().evaluate(
      signal: signal(PaperSignalSide.buy),
      candles: [candle(high: 3621, low: 3595)],
    );
    expect(result.status, PaperSignalStatus.targetHit);
    expect(result.grossR, 2);
  });

  test('SELL stop resolves to -1R', () {
    final result = const PaperTradeLifecycle().evaluate(
      signal: signal(PaperSignalSide.sell),
      candles: [candle(high: 3611, low: 3595)],
    );
    expect(result.status, PaperSignalStatus.stopHit);
    expect(result.grossR, -1);
  });

  test('same candle stop and target is ambiguous', () {
    final result = const PaperTradeLifecycle().evaluate(
      signal: signal(PaperSignalSide.buy),
      candles: [candle(high: 3621, low: 3589)],
    );
    expect(result.status, PaperSignalStatus.ambiguous);
    expect(result.grossR, isNull);
  });

  test('unresolved signal remains pending', () {
    final result = const PaperTradeLifecycle().evaluate(
      signal: signal(PaperSignalSide.buy),
      candles: [candle(high: 3610, low: 3595)],
    );
    expect(result.status, PaperSignalStatus.pending);
    expect(result.grossR, isNull);
  });
}
