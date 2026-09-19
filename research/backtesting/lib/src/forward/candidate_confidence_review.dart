import '../fundamentals/candidate_fundamental_review_service.dart';
import '../fundamentals/gemini_fundamental_review.dart';

enum CandidateConfidenceLevel { standard, strong, highConviction }

final class CandidateConfidenceReview {
  const CandidateConfidenceReview({
    required this.level,
    required this.calibrated,
    required this.supportingReasons,
    required this.cautionReasons,
  });
  final CandidateConfidenceLevel level;
  final bool calibrated;
  final List<String> supportingReasons;
  final List<String> cautionReasons;
}

/// Advisory evidence review for an already-valid candidate.
/// This never creates/rejects a candidate and is not a win probability.
CandidateConfidenceReview buildCandidateConfidenceReview(
  Map<String, Object?> candidate,
  FundamentalReviewResult result, {
  bool forwardCalibrated = false,
}) {
  final support = <String>[];
  final caution = <String>[];
  final side = candidate['side']?.toString().toUpperCase() ?? '';
  final rr = (candidate['riskReward'] as num?)?.toDouble();
  final regime = candidate['regime']?.toString();
  final review = result.review;

  if (rr != null && rr >= 2.0) {
    support.add('Risk/Reward ${rr.toStringAsFixed(2)}R 提供足够的回报空间。');
  } else if (rr != null) {
    caution.add('Risk/Reward ${rr.toStringAsFixed(2)}R 低于 2.00R 参考线。');
  }
  if (regime != null && regime.isNotEmpty) {
    support.add('候选包含明确的 $regime 市场状态。');
  }

  final bias = review.goldBias.toLowerCase();
  final aligned =
      (side == 'BUY' && bias == 'bullish') ||
      (side == 'SELL' && bias == 'bearish');
  final opposed =
      (side == 'BUY' && bias == 'bearish') ||
      (side == 'SELL' && bias == 'bullish');

  if (aligned) {
    support.add('AI 基本面方向与 $side 候选一致。');
  } else if (opposed) {
    caution.add('AI 基本面方向与 $side 候选存在冲突。');
  } else if (review.available) {
    caution.add('AI 基本面方向为 ${review.goldBias}，没有提供明确顺风证据。');
  }

  switch (review.risk) {
    case FundamentalRisk.normal:
      support.add('当前 Fundamental Risk 为 NORMAL。');
    case FundamentalRisk.caution:
      caution.add('当前 Fundamental Risk 为 CAUTION。');
    case FundamentalRisk.highRisk:
      caution.add('当前 Fundamental Risk 为 HIGH RISK。');
  }
  if (!review.available) {
    caution.add('AI Review 当前不可用；候选仍保留，但不提升 Confidence。');
  }

  var level = CandidateConfidenceLevel.standard;
  if (review.available &&
      review.risk == FundamentalRisk.normal &&
      aligned &&
      rr != null &&
      rr >= 2.0) {
    level = CandidateConfidenceLevel.strong;
  }
  if (forwardCalibrated &&
      level == CandidateConfidenceLevel.strong &&
      caution.isEmpty) {
    level = CandidateConfidenceLevel.highConviction;
  }

  return CandidateConfidenceReview(
    level: level,
    calibrated: forwardCalibrated,
    supportingReasons: List.unmodifiable(support),
    cautionReasons: List.unmodifiable(caution),
  );
}
