final class CandidateFinalReview {
  const CandidateFinalReview({
    required this.integrityOk,
    required this.integrityReasons,
  });

  final bool integrityOk;
  final List<String> integrityReasons;
}

CandidateFinalReview buildCandidateFinalReview(Map<String, Object?> candidate) {
  final reasons = <String>[];
  final side = candidate['side']?.toString().toUpperCase();
  final entry = (candidate['entry'] as num?)?.toDouble();
  final stop = (candidate['stopLoss'] as num?)?.toDouble();
  final target = (candidate['takeProfit'] as num?)?.toDouble();
  final rr = (candidate['riskReward'] as num?)?.toDouble();

  final finite =
      entry != null &&
      stop != null &&
      target != null &&
      rr != null &&
      entry.isFinite &&
      stop.isFinite &&
      target.isFinite &&
      rr.isFinite &&
      entry > 0 &&
      stop > 0 &&
      target > 0 &&
      rr > 0;
  if (!finite) {
    return const CandidateFinalReview(
      integrityOk: false,
      integrityReasons: ['Entry / SL / TP / RR 数据不完整或无效。'],
    );
  }

  final geometryOk = switch (side) {
    'BUY' => stop < entry && target > entry,
    'SELL' => stop > entry && target < entry,
    _ => false,
  };
  if (!geometryOk) {
    reasons.add('$side 的 Entry / SL / TP 方向关系无效。');
  }

  final riskDistance = (entry - stop).abs();
  final rewardDistance = (target - entry).abs();
  final derivedRr = riskDistance == 0
      ? double.infinity
      : rewardDistance / riskDistance;
  if (!derivedRr.isFinite || (derivedRr - rr).abs() > 0.05) {
    reasons.add('RR 与 Entry / SL / TP 推导结果不一致。');
  }

  if (reasons.isEmpty) {
    return const CandidateFinalReview(
      integrityOk: true,
      integrityReasons: ['Entry / SL / TP / RR 执行几何完整。'],
    );
  }
  return CandidateFinalReview(
    integrityOk: false,
    integrityReasons: List.unmodifiable(reasons),
  );
}
