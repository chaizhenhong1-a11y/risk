import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_registry/strategy_deployment_policy.dart';
import 'package:tradeforge_backtesting/src/strategy_registry/strategy_deployment_registry.dart';

void main() {
  const registry = StrategyDeploymentRegistry();
  const policy = StrategyDeploymentPolicy();

  test('A and C5 are the only production strategies', () {
    expect(registry.production.map((profile) => profile.id).toSet(), {
      'A',
      'C5',
    });
    expect(policy.mayNotifyUser('A'), isTrue);
    expect(policy.mayNotifyUser('C5'), isTrue);
  });

  test('paper deployment is sourced from frozen V3 portfolio', () {
    final segments = registry.paperSegments.toList();

    expect(segments, hasLength(8));
    expect(segments.map((segment) => segment.id).toSet(), {
      'ATR_EXPANSION|BUY|TREND',
      'TREND_PULLBACK|SELL|RANGE',
      'LIQ_SWEEP|SELL|RANGE',
      'ADX_TREND|BUY|TREND',
      'EMA_MEAN_REVERT|SELL|RANGE',
      'NR7_BREAKOUT|SELL|RANGE',
      'ENGULFING_REVERSAL|SELL|RANGE',
      'ENGULFING_REVERSAL|BUY|TREND',
    });
  });

  test('eight paper segments represent seven distinct strategy ids', () {
    expect(
      registry.paperSegments.map((segment) => segment.strategyId).toSet(),
      hasLength(7),
    );
  });

  test('paper segments never become production user signals', () {
    for (final segment in registry.paperSegments) {
      expect(policy.mayNotifyUser(segment.strategyId), isFalse);
      expect(policy.mayAppearAsUserSignal(segment.strategyId), isFalse);
      expect(
        policy.mayEnterProductionForwardStatistics(segment.strategyId),
        isFalse,
      );
      expect(
        policy.mayEnterPaperForwardStatistics(
          strategyId: segment.strategyId,
          segmentId: segment.id,
        ),
        isTrue,
      );
    }
  });

  test('B remains frozen historical research only', () {
    final b = registry.profile('B')!;

    expect(b.stage, StrategyDeploymentStage.historicalResearch);
    expect(policy.isResearchOnly('B'), isTrue);
    expect(policy.mayNotifyUser('B'), isFalse);
    expect(policy.mayAppearAsUserSignal('B'), isFalse);
    expect(policy.mayEnterProductionForwardStatistics('B'), isFalse);
  });

  test('unknown strategies and fake paper segments are denied', () {
    expect(policy.mayNotifyUser('UNKNOWN'), isFalse);
    expect(policy.mayAppearAsUserSignal('UNKNOWN'), isFalse);
    expect(policy.mayEnterProductionForwardStatistics('UNKNOWN'), isFalse);
    expect(
      policy.mayEnterPaperForwardStatistics(
        strategyId: 'ATR_EXPANSION',
        segmentId: 'ATR_EXPANSION|SELL|RANGE',
      ),
      isFalse,
    );
  });
}
