import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';
import 'package:tradeforge_backtesting/src/strategy_library/paper_forward_segment_portfolio.dart';

void main() {
  ResearchCandidate candidate({
    required String strategy,
    required ResearchSide side,
    required String regime,
    required int minute,
  }) {
    return ResearchCandidate(
      strategyId: strategy,
      observedAt: DateTime.utc(2026, 9, 17, 10).add(Duration(minutes: minute)),
      candleIndex: minute,
      side: side,
      entry: 100,
      stop: side == ResearchSide.buy ? 99 : 101,
      target: side == ResearchSide.buy ? 102 : 98,
      regime: regime,
    );
  }

  test('v1 freezes exactly the four Increment 171 segment hypotheses', () {
    expect(paperForwardSegmentPortfolioV1.map((e) => e.id), <String>[
      'ATR_EXPANSION|BUY|TREND',
      'TREND_PULLBACK|SELL|RANGE',
      'LIQ_SWEEP|SELL|RANGE',
      'ADX_TREND|BUY|TREND',
    ]);
  });

  test('same-side overlapping discoveries become one opportunity cluster', () {
    const portfolio = PaperForwardSegmentPortfolio();
    final input = <PaperForwardPortfolioCandidate>[
      PaperForwardPortfolioCandidate(
        candidate: candidate(
          strategy: 'ATR_EXPANSION',
          side: ResearchSide.buy,
          regime: 'trend',
          minute: 0,
        ),
        segmentId: 'ATR_EXPANSION|BUY|TREND',
      ),
      PaperForwardPortfolioCandidate(
        candidate: candidate(
          strategy: 'ADX_TREND',
          side: ResearchSide.buy,
          regime: 'trend',
          minute: 5,
        ),
        segmentId: 'ADX_TREND|BUY|TREND',
      ),
    ];

    final clusters = portfolio.cluster(input);
    expect(clusters, hasLength(1));
    expect(clusters.single.members, hasLength(2));
  });

  test('opposite sides are preserved as separate candidate clusters', () {
    const portfolio = PaperForwardSegmentPortfolio();
    final input = <PaperForwardPortfolioCandidate>[
      PaperForwardPortfolioCandidate(
        candidate: candidate(
          strategy: 'ATR_EXPANSION',
          side: ResearchSide.buy,
          regime: 'trend',
          minute: 0,
        ),
        segmentId: 'ATR_EXPANSION|BUY|TREND',
      ),
      PaperForwardPortfolioCandidate(
        candidate: candidate(
          strategy: 'LIQ_SWEEP',
          side: ResearchSide.sell,
          regime: 'range',
          minute: 5,
        ),
        segmentId: 'LIQ_SWEEP|SELL|RANGE',
      ),
    ];

    expect(portfolio.cluster(input), hasLength(2));
  });
}
