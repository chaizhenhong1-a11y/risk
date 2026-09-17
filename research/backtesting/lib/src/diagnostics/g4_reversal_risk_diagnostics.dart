final class G4RiskOutcome {
  const G4RiskOutcome({
    required this.riskReward,
    required this.resolved,
    required this.wins,
    required this.losses,
    required this.expired,
    required this.ambiguous,
    required this.expectancyR,
    required this.firstHalfExpectancyR,
    required this.secondHalfExpectancyR,
  });

  final double riskReward;
  final int resolved;
  final int wins;
  final int losses;
  final int expired;
  final int ambiguous;
  final double expectancyR;
  final double firstHalfExpectancyR;
  final double secondHalfExpectancyR;

  double get winRate => resolved == 0 ? 0 : wins / resolved;
}

final class G4ResolvedTrade {
  const G4ResolvedTrade({required this.riskReward, required this.isWin});

  final double riskReward;
  final bool isWin;

  double get resultR => isWin ? riskReward : -1;
}

final class G4ReversalRiskDiagnostics {
  const G4ReversalRiskDiagnostics();

  double expectancy(Iterable<G4ResolvedTrade> trades) {
    final values = trades.toList(growable: false);
    if (values.isEmpty) return 0;
    return values.fold<double>(0, (sum, trade) => sum + trade.resultR) /
        values.length;
  }
}
