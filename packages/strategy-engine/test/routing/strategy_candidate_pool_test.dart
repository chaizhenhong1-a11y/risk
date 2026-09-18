import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';

void main() {
  final time = DateTime.utc(2026, 9, 17, 1);

  StrategyOpportunityCandidate candidate(
    StrategyRouteId strategy,
    TradingBias bias,
  ) => StrategyOpportunityCandidate(
    symbol: 'XAUUSD',
    observedAt: time,
    strategy: strategy,
    bias: bias,
  );

  test('same-time same-direction candidates are de-duplicated', () {
    final result = const StrategyCandidatePool().combine([
      candidate(
        StrategyRouteId.trendPullbackStructureConfirmation,
        TradingBias.buy,
      ),
      candidate(StrategyRouteId.correctionContinuation, TradingBias.buy),
    ]);

    expect(result.conflicts, isEmpty);
    expect(result.opportunities, hasLength(1));
    expect(result.opportunities.single.sources, hasLength(2));
  });

  test('opposite directions become an explicit conflict', () {
    final result = const StrategyCandidatePool().combine([
      candidate(
        StrategyRouteId.trendPullbackStructureConfirmation,
        TradingBias.buy,
      ),
      candidate(StrategyRouteId.correctionContinuation, TradingBias.sell),
    ]);

    expect(result.opportunities, isEmpty);
    expect(result.conflicts, hasLength(1));
  });
}
