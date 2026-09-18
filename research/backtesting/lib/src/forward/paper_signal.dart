enum PaperSignalSide { buy, sell }

enum PaperSignalStatus {
  pending,
  triggered,
  targetHit,
  stopHit,
  expired,
  ambiguous,
  rejected,
}

final class PaperSignal {
  const PaperSignal({
    required this.id,
    required this.symbol,
    required this.strategy,
    required this.side,
    required this.observedAt,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.rewardRisk,
    required this.reason,
    this.status = PaperSignalStatus.pending,
  });

  final String id;
  final String symbol;
  final String strategy;
  final PaperSignalSide side;
  final DateTime observedAt;
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final double rewardRisk;
  final String reason;
  final PaperSignalStatus status;

  static String deterministicId({
    required String symbol,
    required DateTime observedAt,
    required String strategy,
    required PaperSignalSide side,
  }) =>
      '$symbol|${observedAt.toUtc().toIso8601String()}|$strategy|${side.name.toUpperCase()}';

  PaperSignal copyWith({PaperSignalStatus? status}) => PaperSignal(
    id: id,
    symbol: symbol,
    strategy: strategy,
    side: side,
    observedAt: observedAt,
    entry: entry,
    stopLoss: stopLoss,
    takeProfit: takeProfit,
    rewardRisk: rewardRisk,
    reason: reason,
    status: status ?? this.status,
  );
}
