import 'package:signal_engine/signal_engine.dart';

import '../replay/historical_signal_lifecycle_replay.dart';
import 'paper_signal.dart';
import 'paper_strategy_opportunity.dart';

/// Converts Strategy A into a paper opportunity ONLY after the frozen signal
/// lifecycle has reached TRIGGERED.
///
/// READY/waiting candidates are intentionally not published as paper trades.
/// Pre-entry invalidation/expiry are intentionally not converted either.
final class FrozenATriggeredPaperAdapter {
  const FrozenATriggeredPaperAdapter();

  PaperStrategyOpportunity? convert({
    required HistoricalSignalLifecycleState lifecycle,
    required DateTime triggeredAt,
    String symbol = 'XAUUSD',
  }) {
    if (lifecycle.phase != HistoricalSignalLifecyclePhase.triggered) {
      return null;
    }

    final candidate = lifecycle.readyState.candidate;
    final side = switch (candidate.direction) {
      SignalCandidateDirection.buy => PaperSignalSide.buy,
      SignalCandidateDirection.sell => PaperSignalSide.sell,
      SignalCandidateDirection.noTrade => null,
    };
    if (side == null) return null;

    final riskPlan = candidate.riskPlan;
    final riskReward = riskPlan.riskRewardAnalysis.riskReward;
    if (riskReward == null || !riskPlan.riskRewardAnalysis.isValid) {
      throw StateError('Frozen Strategy A has no valid risk/reward geometry.');
    }

    // The frozen RiskPlan already calculated these prices from the explicit
    // historical entry, protective stop, and target. Reuse that exact geometry
    // rather than inventing an Entry Zone midpoint or another execution price.
    final entry = riskReward.entryPrice;
    final stop = riskReward.stopPrice;
    final target = riskReward.targetPrice;

    if (!entry.isFinite || !stop.isFinite || !target.isFinite) {
      throw StateError('Frozen Strategy A emitted non-finite trade geometry.');
    }

    final risk = side == PaperSignalSide.buy ? entry - stop : stop - entry;
    final reward = side == PaperSignalSide.buy
        ? target - entry
        : entry - target;
    if (risk <= 0 || reward <= 0) {
      throw StateError('Frozen Strategy A emitted invalid trade geometry.');
    }

    return PaperStrategyOpportunity(
      symbol: symbol,
      strategy: 'A',
      side: side,
      observedAt: triggeredAt,
      entry: entry,
      stopLoss: stop,
      takeProfit: target,
      reason:
          'Frozen Strategy A; published only after the existing READY -> '
          'TRIGGERED Entry Zone lifecycle transition.',
    );
  }
}
