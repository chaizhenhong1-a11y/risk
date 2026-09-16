import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../bias/multi_timeframe_bias.dart';
import '../confirmation/pullback_confirmation.dart';
import '../pullback/pullback_detector.dart';
import '../scoring/setup_score.dart';
import '../scoring/setup_score_profile.dart';
import '../setup/d1_context_evidence.dart';
import '../setup/entry_confirmation_evidence.dart';
import '../setup/key_level_quality_evidence.dart';
import '../setup/liquidity_evidence.dart';
import '../setup/market_structure_evidence.dart';
import '../setup/setup_evaluation.dart';
import '../setup/setup_evidence_snapshot.dart';

/// Complete Phase 4 strategy-analysis result.
///
/// This is still analysis only. It deliberately contains no Entry, SL, TP, RR,
/// order instruction, or final executable trade signal.
final class StrategySetupAnalysis {
  const StrategySetupAnalysis({
    required this.bias,
    required this.pullback,
    required this.confirmation,
    required this.liquidityEvidence,
    required this.m15StructureEvidence,
    required this.m5ConfirmationEvidence,
    required this.keyLevelQualityEvidence,
    required this.d1ContextEvidence,
    required this.evaluation,
    required this.snapshot,
    required this.score,
    required this.scoreProfileKey,
  });

  final MultiTimeframeBias bias;
  final PullbackAnalysis pullback;
  final PullbackConfirmation confirmation;
  final List<LiquidityEvidence> liquidityEvidence;
  final MarketStructureEvidence m15StructureEvidence;
  final EntryConfirmationEvidence m5ConfirmationEvidence;
  final KeyLevelQualityEvidence keyLevelQualityEvidence;
  final D1ContextEvidence d1ContextEvidence;
  final SetupEvaluation evaluation;
  final SetupEvidenceSnapshot snapshot;
  final SetupScoreResult score;
  final String scoreProfileKey;
}

/// Phase 4 integration boundary for Trend + Pullback strategy analysis.
///
/// Pipeline:
/// H4/H1 bias -> M15 pullback -> rejection -> soft evidence -> eligibility
/// -> immutable evidence snapshot -> research score.
///
/// Lower-level market facts remain inputs. This class coordinates existing
/// deterministic components; it does not duplicate their rules.
final class StrategySetupOrchestrator {
  const StrategySetupOrchestrator({
    this.biasAnalyzer = const MultiTimeframeBiasAnalyzer(),
    this.pullbackDetector = const PullbackDetector(),
    this.confirmationAnalyzer = const PullbackConfirmationAnalyzer(),
    this.liquidityEvidenceEvaluator = const LiquidityEvidenceEvaluator(),
    this.m15StructureEvidenceEvaluator =
        const MarketStructureEvidenceEvaluator(),
    this.m5ConfirmationEvidenceEvaluator =
        const EntryConfirmationEvidenceEvaluator(),
    this.keyLevelQualityEvidenceEvaluator =
        const KeyLevelQualityEvidenceEvaluator(),
    this.d1ContextEvidenceEvaluator = const D1ContextEvidenceEvaluator(),
    this.setupEvaluator = const SetupEvaluator(),
    this.scorer = const SetupScorer(),
  });

  final MultiTimeframeBiasAnalyzer biasAnalyzer;
  final PullbackDetector pullbackDetector;
  final PullbackConfirmationAnalyzer confirmationAnalyzer;
  final LiquidityEvidenceEvaluator liquidityEvidenceEvaluator;
  final MarketStructureEvidenceEvaluator m15StructureEvidenceEvaluator;
  final EntryConfirmationEvidenceEvaluator m5ConfirmationEvidenceEvaluator;
  final KeyLevelQualityEvidenceEvaluator keyLevelQualityEvidenceEvaluator;
  final D1ContextEvidenceEvaluator d1ContextEvidenceEvaluator;
  final SetupEvaluator setupEvaluator;
  final SetupScorer scorer;

  StrategySetupAnalysis analyze({
    required MarketStructure h4Structure,
    required MarketStructure h1Structure,
    required MarketStructure m15Structure,
    required Candle closedM15Candle,
    required Candle closedM5Candle,
    required Iterable<KeyLevel> keyLevels,
    required SetupScoreProfile scoreProfile,
    MarketStructure? d1Structure,
    LevelLiquidityAnalysis? levelLiquidityAnalysis,
    LevelStrength? matchedLevelStrength,
  }) {
    final bias = biasAnalyzer.analyze(
      h4Structure: h4Structure,
      h1Structure: h1Structure,
      d1Context: d1Structure,
    );

    final pullback = pullbackDetector.analyze(
      bias: bias.bias,
      closedCandle: closedM15Candle,
      keyLevels: keyLevels,
    );

    final confirmation = confirmationAnalyzer.analyze(
      bias: bias.bias,
      pullback: pullback,
      closedCandle: closedM15Candle,
    );

    final liquidityEvidence = levelLiquidityAnalysis == null
        ? const <LiquidityEvidence>[
            LiquidityEvidence(
              type: LiquidityEvidenceType.directionalLevelSweep,
              present: false,
            ),
            LiquidityEvidence(
              type: LiquidityEvidenceType.directionalPoolSweep,
              present: false,
            ),
          ]
        : liquidityEvidenceEvaluator.evaluate(
            bias: bias.bias,
            analysis: levelLiquidityAnalysis,
          );

    final m15Evidence = m15StructureEvidenceEvaluator.evaluate(
      bias: bias.bias,
      m15Structure: m15Structure,
    );
    final m5Evidence = m5ConfirmationEvidenceEvaluator.evaluate(
      bias: bias.bias,
      closedM5Candle: closedM5Candle,
    );
    final levelQuality = keyLevelQualityEvidenceEvaluator.evaluate(
      levelStrength: matchedLevelStrength,
    );
    final d1Evidence = d1Structure == null
        ? const D1ContextEvidence(alignment: D1ContextAlignment.unavailable)
        : d1ContextEvidenceEvaluator.evaluate(
            bias: bias.bias,
            d1Structure: d1Structure,
          );

    final evaluation = setupEvaluator.evaluate(
      bias: bias.bias,
      pullback: pullback,
      confirmation: confirmation,
      liquidityEvidence: liquidityEvidence,
      marketStructureEvidence: m15Evidence,
      entryConfirmationEvidence: m5Evidence,
      keyLevelQualityEvidence: levelQuality,
      d1ContextEvidence: d1Evidence,
    );

    final snapshot = SetupEvidenceSnapshot.fromEvaluation(
      evaluation: evaluation,
      d1ContextEvidence: d1Evidence,
      keyLevelQualityEvidence: levelQuality,
    );

    final score = scorer.score(snapshot: snapshot, policy: scoreProfile.policy);

    return StrategySetupAnalysis(
      bias: bias,
      pullback: pullback,
      confirmation: confirmation,
      liquidityEvidence: List.unmodifiable(liquidityEvidence),
      m15StructureEvidence: m15Evidence,
      m5ConfirmationEvidence: m5Evidence,
      keyLevelQualityEvidence: levelQuality,
      d1ContextEvidence: d1Evidence,
      evaluation: evaluation,
      snapshot: snapshot,
      score: score,
      scoreProfileKey: scoreProfile.profileKey,
    );
  }
}
