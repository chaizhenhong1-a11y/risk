import '../forward/biquote_live_market_snapshot.dart';
import 'market_regime_router.dart';
import 'strategy_registry.dart';

final class ResearchStrategyObservation {
  const ResearchStrategyObservation({
    required this.id,
    required this.name,
    required this.family,
    required this.status,
    required this.reason,
  });
  final String id;
  final String name;
  final String family;
  final String status;
  final String reason;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'family': family,
    'status': status,
    'reason': reason,
    'productionEligible': false,
  };
}

/// Makes the expanded library visible during research without turning famous
/// indicators into unvalidated production signals.
final class ResearchStrategyScanner {
  const ResearchStrategyScanner({
    StrategyRegistry registry = const StrategyRegistry(),
    MarketRegimeRouter router = const MarketRegimeRouter(),
  }) : _registry = registry,
       _router = router;
  final StrategyRegistry _registry;
  final MarketRegimeRouter _router;

  (MarketRoute, List<ResearchStrategyObservation>) scan(
    BiQuoteLiveMarketSnapshot snapshot,
  ) {
    final route = _router.route(snapshot);
    final observations = _registry.research
        .map((strategy) {
          final applicable = route.activeFamilies.contains(strategy.family);
          return ResearchStrategyObservation(
            id: strategy.id,
            name: strategy.name,
            family: strategy.family.name,
            status: route.regime == RoutedMarketRegime.warmingUp
                ? 'WARMING_UP'
                : applicable
                ? 'RESEARCH_ACTIVE'
                : 'NOT_APPLICABLE',
            reason: applicable
                ? '当前 ${route.regime.name} 市场允许该策略家族进入研究扫描；尚未获准发正式信号。'
                : '当前 ${route.regime.name} 市场不属于该策略家族。',
          );
        })
        .toList(growable: false);
    return (route, observations);
  }
}
