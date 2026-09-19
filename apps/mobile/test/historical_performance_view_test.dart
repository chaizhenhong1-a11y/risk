import 'package:flutter_test/flutter_test.dart';
import 'package:tradeforge_mobile/src/domain/performance_view.dart';

void main() {
  test('keeps A B C5 historical baseline frozen', () {
    expect(
        historicalPerformanceBaseline.map((x) => x.strategy), ['A', 'B', 'C5']);
  });

  test('contains all eight frozen Paper historical segments', () {
    expect(historicalPaperSegmentBaseline, hasLength(8));
    expect(
      historicalPaperSegmentBaseline
          .map((x) => '${x.strategy}|${x.side}|${x.regime}')
          .toSet(),
      {
        'ATR_EXPANSION|BUY|TREND',
        'TREND_PULLBACK|SELL|RANGE',
        'LIQ_SWEEP|SELL|RANGE',
        'ADX_TREND|BUY|TREND',
        'EMA_MEAN_REVERT|SELL|RANGE',
        'NR7_BREAKOUT|SELL|RANGE',
        'ENGULFING_REVERSAL|SELL|RANGE',
        'ENGULFING_REVERSAL|BUY|TREND',
      },
    );
  });

  test('Increment 220 frozen values remain exact', () {
    final atr = historicalPaperSegmentBaseline.first;
    expect(atr.trades, 347);
    expect(atr.wins, 130);
    expect(atr.losses, 217);
    expect(atr.expectancyR, 0.124);
    expect(atr.profitFactor, 1.198);
    expect(atr.totalR, 43);
    expect(atr.maxDrawdownR, 16);
    expect(atr.yearly, hasLength(2));

    final engulfBuy = historicalPaperSegmentBaseline.last;
    expect(engulfBuy.trades, 926);
    expect(engulfBuy.expectancyR, 0.092);
    expect(engulfBuy.profitFactor, 1.144);
    expect(engulfBuy.maxDrawdownR, 22);
  });
}
