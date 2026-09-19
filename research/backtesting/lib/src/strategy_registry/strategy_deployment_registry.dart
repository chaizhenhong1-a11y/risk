import '../strategy_library/paper_forward_segment_portfolio.dart';

enum StrategyDeploymentStage {
  historicalResearch,
  forwardShadow,
  paper,
  production,
}

final class StrategyDeploymentProfile {
  const StrategyDeploymentProfile({
    required this.id,
    required this.stage,
    required this.userVisibleSignals,
    required this.userNotifications,
    required this.forwardStatistics,
    this.note = '',
  });

  final String id;
  final StrategyDeploymentStage stage;
  final bool userVisibleSignals;
  final bool userNotifications;
  final bool forwardStatistics;
  final String note;

  bool get isResearch =>
      stage == StrategyDeploymentStage.historicalResearch ||
      stage == StrategyDeploymentStage.forwardShadow;
}

/// Single semantic deployment registry.
///
/// Paper segment membership is intentionally sourced from the already-frozen
/// [paperForwardSegmentPortfolioV3]. Do not duplicate that list here.
final class StrategyDeploymentRegistry {
  const StrategyDeploymentRegistry();

  static const productionProfiles = <StrategyDeploymentProfile>[
    StrategyDeploymentProfile(
      id: 'A',
      stage: StrategyDeploymentStage.production,
      userVisibleSignals: true,
      userNotifications: true,
      forwardStatistics: true,
      note: 'Frozen production strategy.',
    ),
    StrategyDeploymentProfile(
      id: 'C5',
      stage: StrategyDeploymentStage.production,
      userVisibleSignals: true,
      userNotifications: true,
      forwardStatistics: true,
      note: 'Frozen production strategy.',
    ),
  ];

  static const researchProfiles = <StrategyDeploymentProfile>[
    StrategyDeploymentProfile(
      id: 'B',
      stage: StrategyDeploymentStage.historicalResearch,
      userVisibleSignals: false,
      userNotifications: false,
      forwardStatistics: false,
      note: 'Frozen research-only Correction Continuation baseline.',
    ),
  ];

  Iterable<StrategyDeploymentProfile> get production => productionProfiles;

  Iterable<PaperForwardSegmentDefinition> get paperSegments =>
      paperForwardSegmentPortfolioV3;

  Iterable<StrategyDeploymentProfile> get research => researchProfiles;

  StrategyDeploymentProfile? profile(String strategy) {
    final normalized = strategy.toUpperCase();
    for (final profile in [...productionProfiles, ...researchProfiles]) {
      if (profile.id == normalized) return profile;
    }
    return null;
  }

  bool isPaperSegment(String segmentId) => paperForwardSegmentPortfolioV3.any(
    (definition) => definition.id.toUpperCase() == segmentId.toUpperCase(),
  );

  bool isPaperStrategy(String strategyId) {
    final normalized = strategyId.toUpperCase();
    return paperForwardSegmentPortfolioV3.any(
      (definition) => definition.strategyId.toUpperCase() == normalized,
    );
  }
}
