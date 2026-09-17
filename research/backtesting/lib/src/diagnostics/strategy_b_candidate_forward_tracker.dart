import 'package:market_models/market_models.dart';

import 'strategy_b_candidate_research_diagnostics.dart';

/// Sequential, no-look-ahead forward labeler for exact Strategy B candidates.
///
/// Candidate-time features are frozen when [registerCandidate] is called.
/// Only later M5 candles are allowed to label continuation/rejection. The
/// candidate candle itself is never observed by a pending sample.
final class StrategyBCandidateForwardTracker {
  StrategyBCandidateForwardTracker({this.horizonsM5 = const [12, 24, 48]}) {
    if (horizonsM5.isEmpty || horizonsM5.any((value) => value <= 0)) {
      throw ArgumentError.value(horizonsM5, 'horizonsM5');
    }
    for (final horizon in horizonsM5) {
      diagnosticsByHorizon[horizon] = StrategyBCandidateResearchDiagnostics();
    }
  }

  final List<int> horizonsM5;
  final Map<int, StrategyBCandidateResearchDiagnostics> diagnosticsByHorizon =
      {};
  final List<_PendingCandidate> _pending = [];
  int registeredCandidates = 0;

  void observeLaterCandle(Candle candle) {
    for (var index = _pending.length - 1; index >= 0; index--) {
      final pending = _pending[index];
      pending.observe(candle);
      if (pending.observedCandles < pending.horizonM5) continue;
      diagnosticsByHorizon[pending.horizonM5]!.add(pending.toSample());
      _pending.removeAt(index);
    }
  }

  void registerCandidate({
    required StrategyBCandidateDirection direction,
    required double referencePrice,
    required double atr,
    required double? rawRiskReward,
    required double? targetRoomAtr,
    required double? pullbackDepthAtr,
    required double? atrRelativeToMedian,
    required bool riskEligible,
  }) {
    if (!atr.isFinite || atr <= 0) return;
    registeredCandidates++;
    for (final horizon in horizonsM5) {
      _pending.add(
        _PendingCandidate(
          horizonM5: horizon,
          direction: direction,
          referencePrice: referencePrice,
          atr: atr,
          rawRiskReward: rawRiskReward,
          targetRoomAtr: targetRoomAtr,
          pullbackDepthAtr: pullbackDepthAtr,
          atrRelativeToMedian: atrRelativeToMedian,
          riskEligible: riskEligible,
        ),
      );
    }
  }

  /// Incomplete end-of-dataset windows are intentionally discarded.
  void finish() => _pending.clear();
}

final class _PendingCandidate {
  _PendingCandidate({
    required this.horizonM5,
    required this.direction,
    required this.referencePrice,
    required this.atr,
    required this.rawRiskReward,
    required this.targetRoomAtr,
    required this.pullbackDepthAtr,
    required this.atrRelativeToMedian,
    required this.riskEligible,
  });

  final int horizonM5;
  final StrategyBCandidateDirection direction;
  final double referencePrice;
  final double atr;
  final double? rawRiskReward;
  final double? targetRoomAtr;
  final double? pullbackDepthAtr;
  final double? atrRelativeToMedian;
  final bool riskEligible;

  int observedCandles = 0;
  bool favorableReached = false;
  bool adverseReached = false;
  StrategyBCandidateOutcome outcome = StrategyBCandidateOutcome.unresolved;

  void observe(Candle candle) {
    observedCandles++;
    if (outcome != StrategyBCandidateOutcome.unresolved) return;

    final favorable = switch (direction) {
      StrategyBCandidateDirection.buy => candle.high - referencePrice,
      StrategyBCandidateDirection.sell => referencePrice - candle.low,
    };
    final adverse = switch (direction) {
      StrategyBCandidateDirection.buy => referencePrice - candle.low,
      StrategyBCandidateDirection.sell => candle.high - referencePrice,
    };

    final favorableNow = favorable >= atr;
    final adverseNow = adverse >= atr;
    if (favorableNow && adverseNow) {
      // Intrabar ordering is unknowable from OHLC, so do not guess.
      favorableReached = true;
      adverseReached = true;
      return;
    }
    if (favorableNow) {
      favorableReached = true;
      outcome = StrategyBCandidateOutcome.continuation;
    } else if (adverseNow) {
      adverseReached = true;
      outcome = StrategyBCandidateOutcome.rejection;
    }
  }

  StrategyBCandidateResearchSample toSample() {
    final resolvedOutcome =
        favorableReached &&
            adverseReached &&
            outcome == StrategyBCandidateOutcome.unresolved
        ? StrategyBCandidateOutcome.unresolved
        : outcome;
    return StrategyBCandidateResearchSample(
      direction: direction,
      rawRiskReward: rawRiskReward,
      targetRoomAtr: targetRoomAtr,
      pullbackDepthAtr: pullbackDepthAtr,
      atrRelativeToMedian: atrRelativeToMedian,
      riskEligible: riskEligible,
      outcome: resolvedOutcome,
    );
  }
}
