enum TradeDirection { buy, sell }

class LiveTradeView {
  const LiveTradeView({
    required this.strategy,
    required this.direction,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.riskReward,
    required this.reason,
    required this.observedAt,
  });

  final String strategy;
  final TradeDirection direction;
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final double riskReward;
  final String reason;
  final DateTime observedAt;

  factory LiveTradeView.fromJson(Map<String, dynamic> json) => LiveTradeView(
        strategy: json['strategy'] as String,
        direction: (json['side'] as String).toLowerCase() == 'sell'
            ? TradeDirection.sell
            : TradeDirection.buy,
        entry: (json['entry'] as num).toDouble(),
        stopLoss: (json['stopLoss'] as num).toDouble(),
        takeProfit: (json['takeProfit'] as num).toDouble(),
        riskReward: (json['riskReward'] as num).toDouble(),
        reason: (json['reason'] as String?) ?? '',
        observedAt: DateTime.parse(json['observedAt'] as String).toLocal(),
      );
}
