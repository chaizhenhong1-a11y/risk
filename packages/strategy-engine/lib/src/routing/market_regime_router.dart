import '../regime/market_regime.dart';

/// Stable identifiers for strategy families that are actually implemented.
///
/// Strategy families with an explicit deterministic specification.
///
/// Registration does not claim profitability. Each family still requires its
/// own historical risk/lifecycle validation before production use.
enum StrategyRouteId {
  trendPullbackStructureConfirmation,
  correctionContinuation,
}

/// Deterministic routing result for one already-classified market regime.
///
/// Routing only decides which strategy families are allowed to evaluate the
/// current context. It does not emit BUY/SELL, score a setup, or bypass any
/// strategy/risk gate.
final class MarketRegimeRoute {
  MarketRegimeRoute({
    required this.regime,
    required this.direction,
    required Iterable<StrategyRouteId> eligibleStrategies,
  }) : eligibleStrategies = Set<StrategyRouteId>.unmodifiable(
         eligibleStrategies,
       );

  final MarketRegime regime;
  final MarketRegimeDirection direction;
  final Set<StrategyRouteId> eligibleStrategies;

  bool get hasEligibleStrategy => eligibleStrategies.isNotEmpty;

  bool allows(StrategyRouteId strategy) =>
      eligibleStrategies.contains(strategy);
}

/// Market-regime to strategy-family eligibility router.
///
/// Increment 087 routing policy:
/// - `trendAligned` -> Strategy A may evaluate.
/// - H4-trend/H1-correction -> Strategy B may evaluate.
/// - range/transition/unknown -> no strategy is registered yet.
///
/// Empty routing means NO STRATEGY AVAILABLE FOR THIS REGIME, not that the
/// market is inherently untradeable. Later independently backtested strategy
/// families can be registered without changing Strategy A.
final class MarketRegimeRouter {
  const MarketRegimeRouter();

  MarketRegimeRoute route(MarketRegimeAnalysis analysis) {
    final strategies = switch (analysis.regime) {
      MarketRegime.trendAligned => const {
        StrategyRouteId.trendPullbackStructureConfirmation,
      },
      MarketRegime.higherTimeframeTrendLowerTimeframeCorrection => const {
        StrategyRouteId.correctionContinuation,
      },
      MarketRegime.range ||
      MarketRegime.transition ||
      MarketRegime.unknown => const <StrategyRouteId>{},
    };

    return MarketRegimeRoute(
      regime: analysis.regime,
      direction: analysis.direction,
      eligibleStrategies: strategies,
    );
  }
}
