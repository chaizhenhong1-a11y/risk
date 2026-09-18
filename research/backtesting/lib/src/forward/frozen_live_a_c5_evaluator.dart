import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../data/mt5_history_adapter.dart';
import '../data/multi_timeframe_backtest_feed.dart';
import '../dataset/strategy_c_episode_validation.dart';
import '../replay/risk_plan_historical_replay.dart';
import '../replay/signal_candidate_historical_replay.dart';
import '../replay/strategy_setup_historical_replay.dart';
import 'biquote_live_market_snapshot.dart';
import 'biquote_strategy_candle_adapter.dart';
import 'frozen_a_incremental_detector.dart';
import 'frozen_c5_episode_detector.dart';
import 'frozen_c5_structural_resolver.dart';
import 'paper_strategy_opportunity.dart';

final class FrozenStrategyDiagnostic {
  const FrozenStrategyDiagnostic({required this.result, required this.reason});

  final String result;
  final String reason;
}

final class FrozenLiveAC5Evaluation {
  const FrozenLiveAC5Evaluation({
    required this.observedAt,
    required this.a,
    required this.c5,
    required this.aDiagnostic,
    required this.c5Diagnostic,
  });

  final DateTime observedAt;
  final PaperStrategyOpportunity? a;
  final PaperStrategyOpportunity? c5;
  final FrozenStrategyDiagnostic aDiagnostic;
  final FrozenStrategyDiagnostic c5Diagnostic;

  Iterable<PaperStrategyOpportunity> get opportunities sync* {
    if (a != null) yield a!;
    if (c5 != null) yield c5!;
  }
}

/// Runs the already-frozen Strategy A and C5 logic on one unseen BiQuote
/// CLOSED-M5 snapshot.
///
/// This is intentionally an adapter around the historical/frozen pipeline:
/// no alternative live-only strategy rules, looser RR gate, score threshold,
/// fallback stop, or opportunity quota is introduced.
final class FrozenLiveAC5Evaluator {
  FrozenLiveAC5Evaluator({
    FrozenAIncrementalDetector? aDetector,
    FrozenC5EpisodeDetector? c5Detector,
    FrozenC5StructuralResolver? c5RiskResolver,
    BiQuoteStrategyCandleAdapter? candleAdapter,
  }) : _aDetector = aDetector ?? FrozenAIncrementalDetector(),
       _c5Detector = c5Detector ?? FrozenC5EpisodeDetector(),
       _c5RiskResolver = c5RiskResolver ?? const FrozenC5StructuralResolver(),
       _candleAdapter = candleAdapter ?? const BiQuoteStrategyCandleAdapter();

  static final StrategyReplayResearchParameters _strategyParameters =
      StrategyReplayResearchParameters(
        equalityTolerance: 0.10,
        zoneHalfWidth: 0.50,
        levelMergeMaxGap: 0.20,
        scoreProfile: SetupScoreProfiles.baselineResearchV1,
      );

  final FrozenAIncrementalDetector _aDetector;
  final FrozenC5EpisodeDetector _c5Detector;
  final FrozenC5StructuralResolver _c5RiskResolver;
  final BiQuoteStrategyCandleAdapter _candleAdapter;
  final AverageTrueRange _atr = const AverageTrueRange();

  FrozenLiveAC5Evaluation evaluate(BiQuoteLiveMarketSnapshot snapshot) {
    final candles = _candleAdapter.snapshot(snapshot);
    final m5 = candles[MarketTimeframe.m5]!;
    final m15 = candles[MarketTimeframe.m15]!;
    final h1 = candles[MarketTimeframe.h1]!;
    final h4 = candles[MarketTimeframe.h4]!;

    if (m5.isEmpty || m15.isEmpty || h1.isEmpty || h4.isEmpty) {
      const reason = '多周期 CLOSED K 线不足，尚未执行冻结策略。';
      return FrozenLiveAC5Evaluation(
        observedAt: snapshot.observedAt,
        a: null,
        c5: null,
        aDiagnostic: const FrozenStrategyDiagnostic(
          result: 'WAITING',
          reason: reason,
        ),
        c5Diagnostic: const FrozenStrategyDiagnostic(
          result: 'WAITING',
          reason: reason,
        ),
      );
    }

    final feed = MultiTimeframeBacktestFeed(
      m5Candles: m5,
      m15Candles: m15,
      h1Candles: h1,
      h4Candles: h4,
    );

    final riskParameters = RiskReplayResearchParameters(
      atrTimeframe: MarketTimeframe.m15,
      atrPeriod: 14,
      atrMultiplier: AtrStopBufferMultiplier(0.50),
      minimumRiskRewardPolicy: MinimumRiskRewardPolicy(2.0),
      entryPriceResolver: (_, analysis) {
        final level = analysis.pullback.matchedLevel;
        if (level == null) {
          throw StateError(
            'Eligible Strategy A setup lost its matched M15 pullback level.',
          );
        }
        return level.midpoint;
      },
    );

    final replay = SignalCandidateHistoricalReplay().create(
      feed: feed,
      riskReplay: RiskPlanHistoricalReplay(),
      strategyReplay: StrategySetupHistoricalReplay(),
      strategyParameters: _strategyParameters,
      riskParameters: riskParameters,
    );

    final step = replay.run().last;
    final source = step.result.riskResult.strategyResult;
    final currentM5 = step.observation.currentM5Candle;

    final aCandidateBuilt = step.result.wasBuilt;
    final a = _aDetector.observe(
      closedM5: currentM5,
      observedAt: snapshot.observedAt,
      candidate: aCandidateBuilt ? step.result.candidate : null,
    );
    final aDiagnostic = FrozenStrategyDiagnostic(
      result: a == null ? 'NO_TRADE' : 'SIGNAL',
      reason: a != null
          ? '冻结 Strategy A 触发，候选已进入 Paper Forward。'
          : aCandidateBuilt
          ? 'A 候选存在，但本根 M5 没有形成新的触发转换。'
          : '冻结 Strategy A 候选条件未同时成立。',
    );

    PaperStrategyOpportunity? c5;
    var c5Diagnostic = const FrozenStrategyDiagnostic(
      result: 'NO_TRADE',
      reason: 'C5 条件未同时成立。',
    );
    if (source.wasAnalyzed) {
      final analysis = source.analysis!;
      final liquidity = source.levelLiquidityAnalysis!;
      final resistanceSweep = liquidity.levelSweeps.any(
        (sweep) => sweep.direction == LiquiditySweepDirection.aboveResistance,
      );
      final hasOtherSweep =
          liquidity.levelSweeps.any(
            (sweep) => sweep.direction == LiquiditySweepDirection.belowSupport,
          ) ||
          liquidity.poolSweeps.isNotEmpty;

      final row = StrategyCEpisodeSample(
        time: snapshot.observedAt,
        h4: analysis.bias.h4Structure.name,
        h1: analysis.bias.h1Structure.name,
        m15: source.m15Structure!.name,
        sweep: resistanceSweep && !hasOtherSweep ? 'resistance' : 'none',
        return12: null,
        return24: null,
        return48: null,
        mfe48: null,
        mae48: null,
      );

      final c5EpisodeStarted = _c5Detector.observe(row);
      if (c5EpisodeStarted && m15.length >= 15) {
        final atr14 = _atr.calculate(candles: m15, period: 14);
        final entry = currentM5.close;
        final supports =
            liquidity.keyLevels
                .where(
                  (level) =>
                      level.isActive &&
                      level.type == KeyLevelType.support &&
                      level.upperBound < entry,
                )
                .toList()
              ..sort((a, b) => b.upperBound.compareTo(a.upperBound));

        if (supports.isNotEmpty) {
          c5 = _c5RiskResolver.resolve(
            episode: row,
            context: FrozenC5StructuralContext(
              time: snapshot.observedAt,
              entryClose: entry,
              m15Atr14: atr14,
              nearestActiveSupportLowerBound: supports.first.lowerBound,
            ),
          );
          c5Diagnostic = const FrozenStrategyDiagnostic(
            result: 'SIGNAL',
            reason: '冻结 C5 episode + 结构止损成立，候选已进入 Paper Forward。',
          );
        } else {
          c5Diagnostic = const FrozenStrategyDiagnostic(
            result: 'NO_TRADE',
            reason: 'C5 episode 已触发，但 entry 下方没有有效 M15 support。',
          );
        }
      } else if (c5EpisodeStarted) {
        c5Diagnostic = const FrozenStrategyDiagnostic(
          result: 'WAITING',
          reason: 'C5 episode 已触发，但 M15 ATR14 历史不足。',
        );
      } else {
        c5Diagnostic = FrozenStrategyDiagnostic(
          result: 'NO_TRADE',
          reason:
              'C5 未触发：H4=${row.h4} / H1=${row.h1} / '
              'M15=${row.m15} / sweep=${row.sweep}。',
        );
      }
    } else {
      _c5Detector.observe(
        StrategyCEpisodeSample(
          time: snapshot.observedAt,
          h4: 'unknown',
          h1: 'unknown',
          m15: 'unknown',
          sweep: 'none',
          return12: null,
          return24: null,
          return48: null,
          mfe48: null,
          mae48: null,
        ),
      );
      c5Diagnostic = const FrozenStrategyDiagnostic(
        result: 'NO_TRADE',
        reason: '当前 M5 未形成可分析的冻结 strategy setup。',
      );
    }

    return FrozenLiveAC5Evaluation(
      observedAt: snapshot.observedAt,
      a: a,
      c5: c5,
      aDiagnostic: aDiagnostic,
      c5Diagnostic: c5Diagnostic,
    );
  }
}
