import '../fundamentals/gemini_fundamental_review.dart';

final class AiReviewConsistencyAudit {
  const AiReviewConsistencyAudit({
    required this.comparable,
    required this.previousSupportPercent,
    required this.currentSupportPercent,
    required this.supportDelta,
    required this.largeSwing,
    required this.reason,
  });

  final bool comparable;
  final int? previousSupportPercent;
  final int? currentSupportPercent;
  final int? supportDelta;
  final bool largeSwing;
  final String reason;

  Map<String, Object?> toJson() => {
    'comparable': comparable,
    'previousSupportPercent': previousSupportPercent,
    'currentSupportPercent': currentSupportPercent,
    'supportDelta': supportDelta,
    'largeSwing': largeSwing,
    'reason': reason,
    'advisoryOnly': true,
  };
}

AiReviewConsistencyAudit auditAiReviewConsistency({
  required Map<String, Object?> candidate,
  required GeminiFundamentalReview current,
  Map<String, Object?>? previousCandidate,
  GeminiFundamentalReview? previous,
  int largeSwingThreshold = 30,
}) {
  if (previousCandidate == null || previous == null) {
    return AiReviewConsistencyAudit(
      comparable: false,
      previousSupportPercent: previous?.supportPercent,
      currentSupportPercent: current.supportPercent,
      supportDelta: null,
      largeSwing: false,
      reason: '没有可比较的上一笔同类 AI 复核。',
    );
  }

  final sameStrategy =
      candidate['strategy']?.toString() ==
      previousCandidate['strategy']?.toString();
  final sameSide =
      candidate['side']?.toString().toUpperCase() ==
      previousCandidate['side']?.toString().toUpperCase();
  final comparable = sameStrategy && sameSide;

  final before = previous.supportPercent;
  final now = current.supportPercent;
  if (!comparable || before == null || now == null) {
    return AiReviewConsistencyAudit(
      comparable: comparable,
      previousSupportPercent: before,
      currentSupportPercent: now,
      supportDelta: null,
      largeSwing: false,
      reason: comparable ? 'AI 百分比不可用，无法比较。' : '策略或方向不同，不进行一致性比较。',
    );
  }

  final delta = (now - before).abs();
  return AiReviewConsistencyAudit(
    comparable: true,
    previousSupportPercent: before,
    currentSupportPercent: now,
    supportDelta: delta,
    largeSwing: delta >= largeSwingThreshold,
    reason: delta >= largeSwingThreshold
        ? '同策略同方向的 AI 支持比例变化较大，需要结合当前行情、新闻和资料时效解释。'
        : '同策略同方向的 AI 支持比例变化处于正常审计范围。',
  );
}
