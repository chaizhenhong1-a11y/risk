import 'strategy_deployment_registry.dart';

final class StrategyDeploymentPolicy {
  const StrategyDeploymentPolicy({
    this.registry = const StrategyDeploymentRegistry(),
  });

  final StrategyDeploymentRegistry registry;

  bool mayNotifyUser(String strategy) =>
      registry.profile(strategy)?.userNotifications ?? false;

  bool mayAppearAsUserSignal(String strategy) =>
      registry.profile(strategy)?.userVisibleSignals ?? false;

  bool mayEnterProductionForwardStatistics(String strategy) =>
      registry.profile(strategy)?.stage == StrategyDeploymentStage.production;

  bool mayEnterPaperForwardStatistics({
    required String strategyId,
    required String segmentId,
  }) =>
      registry.isPaperStrategy(strategyId) &&
      registry.isPaperSegment(segmentId);

  bool isResearchOnly(String strategy) =>
      registry.profile(strategy)?.isResearch ?? false;
}
