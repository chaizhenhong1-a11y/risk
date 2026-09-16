import 'package:market_models/market_models.dart';
import 'package:risk_engine/risk_engine.dart';
import 'package:signal_engine/signal_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const replay = SignalCandidateHistoricalReplay();
  const riskReplay = RiskPlanHistoricalReplay();
  const strategyReplay = StrategySetupHistoricalReplay();

  group('SignalCandidateHistoricalReplay', () {
    test(
      'preserves an upstream strategy skip without fabricating a candidate',
      () {
        final result = replay
            .create(
              feed: _feedAt(m5OpenMinute: 0, m15OpenMinute: 0),
              riskReplay: riskReplay,
              strategyReplay: strategyReplay,
              strategyParameters: _strategyParameters(),
              riskParameters: _riskParameters(),
            )
            .run()
            .single
            .result;

        expect(
          result.decision,
          SignalCandidateReplayDecision.upstreamUnavailable,
        );
        expect(result.candidate, isNull);
        expect(result.riskResult.decision, RiskReplayDecision.strategySkipped);
      },
    );

    test(
      'preserves a blocked strategy result without fabricating a candidate',
      () {
        final result = replay
            .create(
              feed: _feedAt(m5OpenMinute: 10, m15OpenMinute: 0),
              riskReplay: riskReplay,
              strategyReplay: strategyReplay,
              strategyParameters: _strategyParameters(),
              riskParameters: _riskParameters(),
            )
            .run()
            .single
            .result;

        expect(
          result.decision,
          SignalCandidateReplayDecision.upstreamUnavailable,
        );
        expect(result.candidate, isNull);
        expect(result.riskResult.decision, RiskReplayDecision.strategyBlocked);
      },
    );

    test('does not add a score threshold or lifecycle state', () {
      expect(SignalCandidateReplayDecision.values, hasLength(2));
      expect(
        SignalCandidateReplayDecision.values,
        containsAll([
          SignalCandidateReplayDecision.upstreamUnavailable,
          SignalCandidateReplayDecision.built,
        ]),
      );
    });

    test('replay remains lazy through the candidate bridge', () {
      var entryPriceCalls = 0;
      final historicalReplay = replay.create(
        feed: _feedAt(m5OpenMinute: 10, m15OpenMinute: 0),
        riskReplay: riskReplay,
        strategyReplay: strategyReplay,
        strategyParameters: _strategyParameters(),
        riskParameters: RiskReplayResearchParameters(
          atrTimeframe: MarketTimeframe.m15,
          atrPeriod: 14,
          atrMultiplier: AtrStopBufferMultiplier(0.5),
          minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2),
          entryPriceResolver: (_, _) {
            entryPriceCalls++;
            return 2300;
          },
        ),
      );

      expect(entryPriceCalls, 0);
      historicalReplay.run().single;
      // The historical strategy is blocked in this warm-up fixture, so the
      // explicit entry-price resolver must still not be reached.
      expect(entryPriceCalls, 0);
    });

    test('frozen SignalCandidate type is the replay output boundary', () {
      SignalCandidate? candidate;
      expect(candidate, isNull);
    });
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
