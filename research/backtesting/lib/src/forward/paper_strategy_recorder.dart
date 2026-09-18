import 'dart:io';

import 'paper_forward_engine.dart';
import 'paper_signal_activation.dart';
import 'paper_strategy_opportunity.dart';

final class PaperStrategyRecorder {
  const PaperStrategyRecorder({
    this.engine = const PaperForwardEngine(),
    this.activation = const PaperSignalActivation(),
  });

  final PaperForwardEngine engine;
  final PaperSignalActivation activation;

  PaperForwardDecision record(
    File journalFile,
    PaperStrategyOpportunity opportunity,
  ) => engine.record(
    journalFile: journalFile,
    symbol: opportunity.symbol,
    strategy: opportunity.strategy,
    side: opportunity.side,
    observedAt: opportunity.observedAt,
    entry: opportunity.entry,
    stopLoss: opportunity.stopLoss,
    takeProfit: opportunity.takeProfit,
    reason: opportunity.reason,
    status: activation.initialStatusFor(opportunity.strategy),
  );
}
