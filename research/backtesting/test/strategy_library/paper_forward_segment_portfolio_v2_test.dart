import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/paper_forward_segment_portfolio.dart';

void main() {
  test(
    'Increment 185 portfolio preserves V1 and adds EMA mean-revert SELL range',
    () {
      expect(paperForwardSegmentPortfolioV1, hasLength(4));
      expect(paperForwardSegmentPortfolioV2, hasLength(5));
      expect(
        paperForwardSegmentPortfolioV2.map((e) => e.id),
        containsAll(<String>[
          'ATR_EXPANSION|BUY|TREND',
          'TREND_PULLBACK|SELL|RANGE',
          'LIQ_SWEEP|SELL|RANGE',
          'ADX_TREND|BUY|TREND',
          'EMA_MEAN_REVERT|SELL|RANGE',
        ]),
      );
    },
  );
}
