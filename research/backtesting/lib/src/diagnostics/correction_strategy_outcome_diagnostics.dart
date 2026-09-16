import 'package:market_models/market_models.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

/// Research-only Strategy B trigger hypotheses.
///
/// None of these are trading rules. Increment 086 measures what happens after
/// each observable event so a later increment can specify Strategy B from
/// evidence rather than intuition.
enum CorrectionOutcomeHypothesis {
  m15RealignedWithH4,
  directionalSweep,
  sweepAndM15Realigned,
  sweepThenM15Realigned,
}

/// Aggregate forward outcome for one hypothesis and one fixed M5 horizon.
final class CorrectionForwardOutcomeSummary {
  int triggers = 0;
  int resolved = 0;
  int ambiguousOneAtrBarrier = 0;
  int favorableOneAtrFirst = 0;
  int adverseOneAtrFirst = 0;
  int neitherOneAtrBarrier = 0;
  int ambiguousTwoToOneBarrier = 0;
  int favorableTwoAtrBeforeAdverseOneAtr = 0;
  int adverseOneAtrBeforeFavorableTwoAtr = 0;
  int neitherTwoToOneBarrier = 0;
  double _mfeAtrTotal = 0;
  double _maeAtrTotal = 0;

  double get averageMfeAtr => resolved == 0 ? 0 : _mfeAtrTotal / resolved;
  double get averageMaeAtr => resolved == 0 ? 0 : _maeAtrTotal / resolved;

  double get favorableOneAtrFirstShare =>
      resolved == 0 ? 0 : favorableOneAtrFirst / resolved;

  double get favorableTwoToOneShare =>
      resolved == 0 ? 0 : favorableTwoAtrBeforeAdverseOneAtr / resolved;

  void _addResolved(_PendingCorrectionOutcome outcome) {
    resolved++;
    _mfeAtrTotal += outcome.maximumFavorableExcursion / outcome.atr;
    _maeAtrTotal += outcome.maximumAdverseExcursion / outcome.atr;

    switch (outcome.oneAtrBarrierResult) {
      case _BarrierResult.favorable:
        favorableOneAtrFirst++;
      case _BarrierResult.adverse:
        adverseOneAtrFirst++;
      case _BarrierResult.ambiguous:
        ambiguousOneAtrBarrier++;
      case _BarrierResult.neither:
        neitherOneAtrBarrier++;
    }

    switch (outcome.twoToOneBarrierResult) {
      case _BarrierResult.favorable:
        favorableTwoAtrBeforeAdverseOneAtr++;
      case _BarrierResult.adverse:
        adverseOneAtrBeforeFavorableTwoAtr++;
      case _BarrierResult.ambiguous:
        ambiguousTwoToOneBarrier++;
      case _BarrierResult.neither:
        neitherTwoToOneBarrier++;
    }
  }
}

/// Sequential, no-look-ahead collector for Strategy B outcome research.
///
/// Trigger detection uses only facts visible at the current M5 close. Outcomes
/// are then accumulated strictly from later M5 candles; the trigger candle is
/// deliberately excluded. ATR is supplied from CLOSED M15 history.
final class CorrectionStrategyOutcomeDiagnostics {
  CorrectionStrategyOutcomeDiagnostics({this.horizonsM5 = const [12, 24, 48]}) {
    if (horizonsM5.isEmpty || horizonsM5.any((value) => value <= 0)) {
      throw ArgumentError.value(
        horizonsM5,
        'horizonsM5',
        'must contain positive M5 candle counts',
      );
    }
    if (horizonsM5.toSet().length != horizonsM5.length) {
      throw ArgumentError.value(horizonsM5, 'horizonsM5', 'must be unique');
    }
    for (final hypothesis in CorrectionOutcomeHypothesis.values) {
      summaries[hypothesis] = {
        for (final horizon in horizonsM5)
          horizon: CorrectionForwardOutcomeSummary(),
      };
    }
  }

  final List<int> horizonsM5;
  final Map<
    CorrectionOutcomeHypothesis,
    Map<int, CorrectionForwardOutcomeSummary>
  >
  summaries = {};

  final List<_PendingCorrectionOutcome> _pending = [];
  MarketRegimeDirection? _episodeDirection;
  bool _episodeSawDirectionalSweep = false;
  bool _previousAligned = false;
  bool _previousSweep = false;
  bool _previousSweepAndAligned = false;
  bool _sweepThenRealignAlreadyTriggered = false;

  void observe({
    required Candle currentM5Candle,
    required MarketRegimeAnalysis regimeAnalysis,
    required MarketStructure m15Structure,
    required LevelLiquidityAnalysis levelLiquidityAnalysis,
    required double? m15Atr,
  }) {
    _advancePending(currentM5Candle);

    if (regimeAnalysis.regime !=
        MarketRegime.higherTimeframeTrendLowerTimeframeCorrection) {
      _resetEpisode();
      return;
    }

    final direction = regimeAnalysis.direction;
    if (direction == MarketRegimeDirection.none) {
      throw StateError('Correction regime must retain an H4 direction.');
    }
    if (_episodeDirection != direction) {
      _resetEpisode();
      _episodeDirection = direction;
    }

    final aligned = _isAligned(m15Structure, direction);
    final sweep = _hasDirectionalSweep(levelLiquidityAnalysis, direction);
    final sweepAndAligned = sweep && aligned;
    final hadSweepBeforeThisObservation = _episodeSawDirectionalSweep;

    if (m15Atr != null && m15Atr.isFinite && m15Atr > 0) {
      if (aligned && !_previousAligned) {
        _trigger(
          CorrectionOutcomeHypothesis.m15RealignedWithH4,
          currentM5Candle,
          direction,
          m15Atr,
        );
      }
      if (sweep && !_previousSweep) {
        _trigger(
          CorrectionOutcomeHypothesis.directionalSweep,
          currentM5Candle,
          direction,
          m15Atr,
        );
      }
      if (sweepAndAligned && !_previousSweepAndAligned) {
        _trigger(
          CorrectionOutcomeHypothesis.sweepAndM15Realigned,
          currentM5Candle,
          direction,
          m15Atr,
        );
      }
      if (aligned &&
          !_previousAligned &&
          hadSweepBeforeThisObservation &&
          !_sweepThenRealignAlreadyTriggered) {
        _trigger(
          CorrectionOutcomeHypothesis.sweepThenM15Realigned,
          currentM5Candle,
          direction,
          m15Atr,
        );
        _sweepThenRealignAlreadyTriggered = true;
      }
    }

    if (sweep) _episodeSawDirectionalSweep = true;
    _previousAligned = aligned;
    _previousSweep = sweep;
    _previousSweepAndAligned = sweepAndAligned;
  }

  /// Drops incomplete end-of-dataset forward windows rather than pretending
  /// they were resolved outcomes.
  void finish() => _pending.clear();

  void _trigger(
    CorrectionOutcomeHypothesis hypothesis,
    Candle triggerCandle,
    MarketRegimeDirection direction,
    double atr,
  ) {
    for (final horizon in horizonsM5) {
      summaries[hypothesis]![horizon]!.triggers++;
      _pending.add(
        _PendingCorrectionOutcome(
          hypothesis: hypothesis,
          horizonM5: horizon,
          entryPrice: triggerCandle.close,
          direction: direction,
          atr: atr,
        ),
      );
    }
  }

  void _advancePending(Candle candle) {
    for (var index = _pending.length - 1; index >= 0; index--) {
      final pending = _pending[index];
      pending.observe(candle);
      if (pending.observedCandles >= pending.horizonM5) {
        summaries[pending.hypothesis]![pending.horizonM5]!._addResolved(
          pending,
        );
        _pending.removeAt(index);
      }
    }
  }

  void _resetEpisode() {
    _episodeDirection = null;
    _episodeSawDirectionalSweep = false;
    _previousAligned = false;
    _previousSweep = false;
    _previousSweepAndAligned = false;
    _sweepThenRealignAlreadyTriggered = false;
  }

  bool _isAligned(MarketStructure structure, MarketRegimeDirection direction) =>
      (direction == MarketRegimeDirection.bullish &&
          structure == MarketStructure.bullish) ||
      (direction == MarketRegimeDirection.bearish &&
          structure == MarketStructure.bearish);

  bool _hasDirectionalSweep(
    LevelLiquidityAnalysis analysis,
    MarketRegimeDirection direction,
  ) {
    final levelSweep = analysis.levelSweeps.any(
      (sweep) => switch (direction) {
        MarketRegimeDirection.bullish =>
          sweep.direction == LiquiditySweepDirection.belowSupport,
        MarketRegimeDirection.bearish =>
          sweep.direction == LiquiditySweepDirection.aboveResistance,
        MarketRegimeDirection.none => false,
      },
    );
    final poolSweep = analysis.poolSweeps.any(
      (sweep) => switch (direction) {
        MarketRegimeDirection.bullish =>
          sweep.direction == LiquidityPoolSweepDirection.belowEqualLows,
        MarketRegimeDirection.bearish =>
          sweep.direction == LiquidityPoolSweepDirection.aboveEqualHighs,
        MarketRegimeDirection.none => false,
      },
    );
    return levelSweep || poolSweep;
  }
}

enum _BarrierResult { favorable, adverse, ambiguous, neither }

final class _PendingCorrectionOutcome {
  _PendingCorrectionOutcome({
    required this.hypothesis,
    required this.horizonM5,
    required this.entryPrice,
    required this.direction,
    required this.atr,
  });

  final CorrectionOutcomeHypothesis hypothesis;
  final int horizonM5;
  final double entryPrice;
  final MarketRegimeDirection direction;
  final double atr;

  int observedCandles = 0;
  double maximumFavorableExcursion = 0;
  double maximumAdverseExcursion = 0;
  _BarrierResult oneAtrBarrierResult = _BarrierResult.neither;
  _BarrierResult twoToOneBarrierResult = _BarrierResult.neither;

  void observe(Candle candle) {
    observedCandles++;
    final favorable = switch (direction) {
      MarketRegimeDirection.bullish => candle.high - entryPrice,
      MarketRegimeDirection.bearish => entryPrice - candle.low,
      MarketRegimeDirection.none => throw StateError(
        'Outcome needs direction.',
      ),
    };
    final adverse = switch (direction) {
      MarketRegimeDirection.bullish => entryPrice - candle.low,
      MarketRegimeDirection.bearish => candle.high - entryPrice,
      MarketRegimeDirection.none => throw StateError(
        'Outcome needs direction.',
      ),
    };
    if (favorable > maximumFavorableExcursion) {
      maximumFavorableExcursion = favorable;
    }
    if (adverse > maximumAdverseExcursion) {
      maximumAdverseExcursion = adverse;
    }

    if (oneAtrBarrierResult == _BarrierResult.neither) {
      oneAtrBarrierResult = _resolveBarrier(
        favorableReached: favorable >= atr,
        adverseReached: adverse >= atr,
      );
    }
    if (twoToOneBarrierResult == _BarrierResult.neither) {
      twoToOneBarrierResult = _resolveBarrier(
        favorableReached: favorable >= 2 * atr,
        adverseReached: adverse >= atr,
      );
    }
  }

  _BarrierResult _resolveBarrier({
    required bool favorableReached,
    required bool adverseReached,
  }) {
    if (favorableReached && adverseReached) return _BarrierResult.ambiguous;
    if (favorableReached) return _BarrierResult.favorable;
    if (adverseReached) return _BarrierResult.adverse;
    return _BarrierResult.neither;
  }
}
