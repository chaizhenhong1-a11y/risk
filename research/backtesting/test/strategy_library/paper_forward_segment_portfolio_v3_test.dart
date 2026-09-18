import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_segment_paper_forward_bridge.dart';
import 'package:tradeforge_backtesting/src/strategy_library/paper_forward_segment_portfolio.dart';

void main() {
  test(
    'Increment 189 freezes Portfolio V3 at eight paper-forward segments',
    () {
      expect(paperForwardSegmentPortfolioV1, hasLength(4));
      expect(paperForwardSegmentPortfolioV2, hasLength(5));
      expect(paperForwardSegmentPortfolioV3, hasLength(8));

      expect(
        paperForwardSegmentPortfolioV3.map((e) => e.id),
        containsAll(<String>[
          'ATR_EXPANSION|BUY|TREND',
          'TREND_PULLBACK|SELL|RANGE',
          'LIQ_SWEEP|SELL|RANGE',
          'ADX_TREND|BUY|TREND',
          'EMA_MEAN_REVERT|SELL|RANGE',
          'NR7_BREAKOUT|SELL|RANGE',
          'ENGULFING_REVERSAL|SELL|RANGE',
          'ENGULFING_REVERSAL|BUY|TREND',
        ]),
      );
    },
  );

  test(
    'default portfolio and BiQuote bridge use V3 without changing state schema',
    () {
      const portfolio = PaperForwardSegmentPortfolio();
      expect(portfolio.definitions, same(paperForwardSegmentPortfolioV3));

      final temp = Directory.systemTemp.createTempSync('tradeforge_inc189_');
      addTearDown(() => temp.deleteSync(recursive: true));

      final bridge = BiQuoteSegmentPaperForwardBridge(
        startAt: DateTime.utc(2026, 9, 18),
        stateFile: File('${temp.path}/state.json'),
        journalFile: File('${temp.path}/journal.jsonl'),
      );

      expect(bridge.portfolio.definitions, hasLength(8));
      expect(
        bridge.portfolio.definitions.map((e) => e.id),
        contains('NR7_BREAKOUT|SELL|RANGE'),
      );
    },
  );
}
