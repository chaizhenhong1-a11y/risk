import 'paper_signal.dart';

/// Strategy-owned opportunity geometry handed to the paper-forward boundary.
///
/// This type deliberately does not score or filter opportunities. Frozen
/// strategy/risk pipelines remain responsible for deciding that an
/// opportunity exists and for producing Entry / SL / TP.
final class PaperStrategyOpportunity {
  const PaperStrategyOpportunity({
    required this.symbol,
    required this.strategy,
    required this.side,
    required this.observedAt,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.reason,
  });

  final String symbol;
  final String strategy;
  final PaperSignalSide side;
  final DateTime observedAt;
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final String reason;
}
