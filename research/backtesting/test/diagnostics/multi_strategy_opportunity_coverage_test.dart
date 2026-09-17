import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  test('consecutive Strategy A eligibility is one episode', () {
    final coverage = MultiStrategyOpportunityCoverage();
    final day = DateTime(2026, 9, 17);
    coverage.observeTradingDate(day);

    coverage.observeStrategyA(
      observedAt: day.add(const Duration(minutes: 5)),
      eligible: true,
      bias: TradingBias.buy,
    );
    coverage.observeStrategyA(
      observedAt: day.add(const Duration(minutes: 10)),
      eligible: true,
      bias: TradingBias.buy,
    );
    coverage.observeStrategyA(
      observedAt: day.add(const Duration(minutes: 15)),
      eligible: false,
      bias: TradingBias.noTrade,
    );
    coverage.observeStrategyA(
      observedAt: day.add(const Duration(minutes: 20)),
      eligible: true,
      bias: TradingBias.buy,
    );

    final report = coverage.finish();
    expect(report.strategyACandidates, 2);
    expect(report.uniqueOpportunities, 2);
  });

  test('same-time same-direction A+B counts once', () {
    final coverage = MultiStrategyOpportunityCoverage();
    final time = DateTime(2026, 9, 17, 8);
    coverage.observeTradingDate(time);
    coverage.observeStrategyA(
      observedAt: time,
      eligible: true,
      bias: TradingBias.sell,
    );
    coverage.observeStrategyB(
      observedAt: time,
      eligible: true,
      bias: TradingBias.sell,
    );

    final report = coverage.finish();
    expect(report.sameDirectionOverlaps, 1);
    expect(report.uniqueOpportunities, 1);
  });
}
