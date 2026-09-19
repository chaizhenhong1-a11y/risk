enum FundamentalRisk { normal, caution, highRisk }

final class GeminiFundamentalReview {
  const GeminiFundamentalReview({
    required this.available,
    required this.risk,
    required this.goldBias,
    required this.summary,
    required this.relevantFactors,
    required this.model,
    this.candidateSummary = '',
    this.technicalReasons = const <String>[],
    this.riskReasons = const <String>[],
    this.supportPercent,
    this.opposePercent,
    this.reason,
  });

  final bool available;
  final FundamentalRisk risk;
  final String goldBias;
  final String summary;
  final List<String> relevantFactors;
  final String candidateSummary;
  final List<String> technicalReasons;
  final List<String> riskReasons;

  /// AI 对当前策略候选的复核倾向，不是胜率，也不是交易 Gate。
  final int? supportPercent;

  /// AI 对当前策略候选的反对倾向，不是亏损概率，也不是交易 Gate。
  final int? opposePercent;

  final String model;
  final String? reason;

  factory GeminiFundamentalReview.unavailable({
    required String model,
    required String reason,
  }) => GeminiFundamentalReview(
    available: false,
    risk: FundamentalRisk.normal,
    goldBias: 'unclear',
    summary:
        'AI fundamental review unavailable; strategy candidate remains valid.',
    relevantFactors: const [],
    candidateSummary:
        'AI candidate review unavailable; TradeForge keeps the strategy candidate.',
    technicalReasons: const [],
    riskReasons: const [],
    supportPercent: null,
    opposePercent: null,
    model: model,
    reason: reason,
  );
}
