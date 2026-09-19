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
    model: model,
    reason: reason,
  );
}
