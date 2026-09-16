import 'package:market_models/market_models.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const replay = StrategySetupHistoricalReplay();

  group('StrategySetupHistoricalReplay', () {
    test('skips historical M5 steps until an M15 candle has closed', () {
      final steps = replay
          .create(
            feed: MultiTimeframeBacktestFeed(
              m5Candles: [_candle(10, 0, const Duration(minutes: 5))],
              m15Candles: [_candle(10, 0, const Duration(minutes: 15))],
              h1Candles: const [],
              h4Candles: const [],
            ),
            parameters: _parameters(),
          )
          .run()
          .toList();

      expect(steps, hasLength(1));
      expect(steps.single.result.wasAnalyzed, isFalse);
      expect(
        steps.single.result.skipReason,
        StrategyReplaySkipReason.noClosedM15Candle,
      );
    });

    test('runs the real Phase 4 pipeline once M15 history is closed', () {
      final steps = replay
          .create(
            feed: MultiTimeframeBacktestFeed(
              m5Candles: [_candle(10, 10, const Duration(minutes: 5))],
              m15Candles: [_candle(10, 0, const Duration(minutes: 15))],
              h1Candles: const [],
              h4Candles: const [],
            ),
            parameters: _parameters(),
          )
          .run()
          .toList();

      final result = steps.single.result;

      expect(result.wasAnalyzed, isTrue);
      expect(result.analysis, isNotNull);
      expect(
        result.analysis!.scoreProfileKey,
        SetupScoreProfiles.baselineResearchV1.profileKey,
      );
      // With no confirmed H4/H1 structure yet, the frozen strategy engine
      // must naturally block rather than the replay inventing a direction.
      expect(result.analysis!.evaluation.isEligible, isFalse);
    });

    test('does not expose the still-open M15 candle to strategy analysis', () {
      final steps = replay
          .create(
            feed: MultiTimeframeBacktestFeed(
              m5Candles: [_candle(10, 5, const Duration(minutes: 5))],
              m15Candles: [_candle(10, 0, const Duration(minutes: 15))],
              h1Candles: const [],
              h4Candles: const [],
            ),
            parameters: _parameters(),
          )
          .run()
          .toList();

      expect(steps.single.result.wasAnalyzed, isFalse);
    });

    test(
      'cached higher-timeframe analysis refreshes only as closed history advances',
      () {
        final steps = replay
            .create(
              feed: MultiTimeframeBacktestFeed(
                m5Candles: [
                  _candle(10, 10, const Duration(minutes: 5)),
                  _candle(10, 15, const Duration(minutes: 5)),
                  _candle(10, 25, const Duration(minutes: 5)),
                ],
                m15Candles: [
                  _candle(10, 0, const Duration(minutes: 15)),
                  _candle(10, 15, const Duration(minutes: 15)),
                ],
                h1Candles: const [],
                h4Candles: const [],
              ),
              parameters: _parameters(),
            )
            .run()
            .toList();

        expect(steps, hasLength(3));
        expect(steps.every((step) => step.result.wasAnalyzed), isTrue);
        expect(
          steps[0].result.analysis!.scoreProfileKey,
          steps[1].result.analysis!.scoreProfileKey,
        );
        expect(
          steps[2].observation.historyFor(MarketTimeframe.m15),
          hasLength(2),
        );
        expect(steps[2].result.levelLiquidityAnalysis, isNotNull);
      },
    );

    test('research parameters are explicit and validated', () {
      expect(
        () => replay.create(
          feed: MultiTimeframeBacktestFeed(
            m5Candles: const [],
            m15Candles: const [],
            h1Candles: const [],
            h4Candles: const [],
          ),
          parameters: StrategyReplayResearchParameters(
            equalityTolerance: -0.1,
            zoneHalfWidth: 0.5,
            levelMergeMaxGap: 0.2,
            scoreProfile: SetupScoreProfiles.baselineResearchV1,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('D1 and level strength are not fabricated by the replay layer', () {
      final result = replay
          .create(
            feed: MultiTimeframeBacktestFeed(
              m5Candles: [_candle(10, 10, const Duration(minutes: 5))],
              m15Candles: [_candle(10, 0, const Duration(minutes: 15))],
              h1Candles: const [],
              h4Candles: const [],
            ),
            parameters: _parameters(),
          )
          .run()
          .single
          .result;

      expect(result.analysis, isNotNull);
      expect(
        result.analysis!.d1ContextEvidence.alignment,
        D1ContextAlignment.unavailable,
      );
      expect(result.analysis!.keyLevelQualityEvidence.present, isFalse);
    });
  });
}

StrategyReplayResearchParameters _parameters() {
  return StrategyReplayResearchParameters(
    equalityTolerance: 0.1,
    zoneHalfWidth: 0.5,
    levelMergeMaxGap: 0.2,
    scoreProfile: SetupScoreProfiles.baselineResearchV1,
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
