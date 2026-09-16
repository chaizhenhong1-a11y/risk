import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const planner = DirectionalLevelRiskPlanOrchestrator();

  test('BUY selects nearest active support below reference price', () {
    final result = planner.analyze(
      bias: TradingBias.buy,
      referencePrice: 2305,
      atr: 2,
      atrMultiplier: AtrStopBufferMultiplier(0.5),
      keyLevels: [
        _support(2290, 2292, 1),
        _support(2299, 2301, 2),
        _resistance(2310, 2312, 3),
      ],
      minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
    );

    expect(result, isNotNull);
    expect(result!.entryZoneAnalysis.zone!.midpoint, 2300);
    expect(result.protectiveStopAnalysis.stop!.price, 2298);
    expect(result.targetAnalysis.target!.price, 2310);
    expect(result.isEligible, isTrue);
  });

  test('SELL selects nearest active resistance above reference price', () {
    final result = planner.analyze(
      bias: TradingBias.sell,
      referencePrice: 2300,
      atr: 2,
      atrMultiplier: AtrStopBufferMultiplier(0.5),
      keyLevels: [
        _resistance(2304, 2306, 1),
        _resistance(2310, 2312, 2),
        _support(2290, 2292, 3),
      ],
      minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
    );

    expect(result, isNotNull);
    expect(result!.entryZoneAnalysis.zone!.midpoint, 2305);
    expect(result.protectiveStopAnalysis.stop!.price, 2307);
    expect(result.targetAnalysis.target!.price, 2292);
    expect(result.isEligible, isTrue);
  });

  test('returns null rather than inventing an entry level', () {
    final result = planner.analyze(
      bias: TradingBias.buy,
      referencePrice: 2300,
      atr: 2,
      atrMultiplier: AtrStopBufferMultiplier(0.5),
      keyLevels: [_resistance(2310, 2312, 1)],
      minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
    );

    expect(result, isNull);
  });
}

KeyLevel _support(double lower, double upper, int index) => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);

KeyLevel _resistance(double lower, double upper, int index) => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: lower,
  upperBound: upper,
  createdAtCandleIndex: index,
);
