import 'package:market_models/market_models.dart';
import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const riskReplay = RiskPlanHistoricalReplay();
  const strategyReplay = StrategySetupHistoricalReplay();

  group('RiskPlanHistoricalReplay', () {
    test('preserves a strategy skip before risk planning', () {
      final result = riskReplay
          .create(
            feed: _feedAt(m5OpenMinute: 0, m15OpenMinute: 0),
            strategyReplay: strategyReplay,
            strategyParameters: _strategyParameters(),
            riskParameters: _riskParameters(),
          )
          .run()
          .single
          .result;

      expect(result.decision, RiskReplayDecision.strategySkipped);
      expect(result.riskPlan, isNull);
      expect(result.atr, isNull);
      expect(result.entryPrice, isNull);
    });

    test('does not calculate risk for a blocked historical strategy setup', () {
      final result = riskReplay
          .create(
            feed: _feedAt(m5OpenMinute: 10, m15OpenMinute: 0),
            strategyReplay: strategyReplay,
            strategyParameters: _strategyParameters(),
            riskParameters: _riskParameters(),
          )
          .run()
          .single
          .result;

      expect(result.strategyResult.wasAnalyzed, isTrue);
      expect(result.strategyResult.analysis!.snapshot.isEligible, isFalse);
      expect(result.decision, RiskReplayDecision.strategyBlocked);
      expect(result.riskPlan, isNull);
    });

    test('entry-price resolver is not called for blocked setups', () {
      var calls = 0;

      final result = riskReplay
          .create(
            feed: _feedAt(m5OpenMinute: 10, m15OpenMinute: 0),
            strategyReplay: strategyReplay,
            strategyParameters: _strategyParameters(),
            riskParameters: RiskReplayResearchParameters(
              atrTimeframe: MarketTimeframe.m15,
              atrPeriod: 14,
              atrMultiplier: AtrStopBufferMultiplier(0.5),
              minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
              entryPriceResolver: (_, _) {
                calls++;
                return 2300;
              },
            ),
          )
          .run()
          .single
          .result;

      expect(result.decision, RiskReplayDecision.strategyBlocked);
      expect(calls, 0);
    });

    test('rejects a non-positive ATR period explicitly', () {
      expect(
        () => riskReplay.create(
          feed: _feedAt(m5OpenMinute: 10, m15OpenMinute: 0),
          strategyReplay: strategyReplay,
          strategyParameters: _strategyParameters(),
          riskParameters: RiskReplayResearchParameters(
            atrTimeframe: MarketTimeframe.m15,
            atrPeriod: 0,
            atrMultiplier: AtrStopBufferMultiplier(0.5),
            minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
            entryPriceResolver: (_, _) => 2300,
          ),
        ),
        throwsArgumentError,
      );
    });

    test(
      'strategy replay retains the exact historical level/liquidity facts',
      () {
        final strategyResult = strategyReplay
            .create(
              feed: _feedAt(m5OpenMinute: 10, m15OpenMinute: 0),
              parameters: _strategyParameters(),
            )
            .run()
            .single
            .result;

        expect(strategyResult.wasAnalyzed, isTrue);
        expect(strategyResult.levelLiquidityAnalysis, isNotNull);
        expect(strategyResult.levelLiquidityAnalysis!.keyLevels, isA<List>());
      },
    );
  });
}

StrategyReplayResearchParameters _strategyParameters() {
  return StrategyReplayResearchParameters(
    equalityTolerance: 0.1,
    zoneHalfWidth: 0.5,
    levelMergeMaxGap: 0.2,
    scoreProfile: SetupScoreProfiles.baselineResearchV1,
  );
}

RiskReplayResearchParameters _riskParameters() {
  return RiskReplayResearchParameters(
    atrTimeframe: MarketTimeframe.m15,
    atrPeriod: 14,
    atrMultiplier: AtrStopBufferMultiplier(0.5),
    minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
    entryPriceResolver: (_, _) => 2300,
  );
}

MultiTimeframeBacktestFeed _feedAt({
  required int m5OpenMinute,
  required int m15OpenMinute,
}) {
  return MultiTimeframeBacktestFeed(
    m5Candles: [_candle(10, m5OpenMinute, const Duration(minutes: 5))],
    m15Candles: [_candle(10, m15OpenMinute, const Duration(minutes: 15))],
    h1Candles: const [],
    h4Candles: const [],
  );
}

Candle _candle(int hour, int minute, Duration duration) {
  final openTime = DateTime.utc(2026, 1, 5, hour, minute);
  return Candle(
    openTime: openTime,
    closeTime: openTime.add(duration),
    open: 2300,
    high: 2302,
    low: 2298,
    close: 2301,
    volume: 100,
  );
}
