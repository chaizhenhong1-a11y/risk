enum FundamentalRisk { normal, caution, highRisk }

final class GeminiFundamentalReview {
  const GeminiFundamentalReview({
    required this.available,
    required this.risk,
    required this.goldBias,
    required this.summary,
    required this.relevantFactors,
    required this.model,
    this.reason,
  });
  final bool available;
  final FundamentalRisk risk;
  final String goldBias;
  final String summary;
  final List<String> relevantFactors;
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
    model: model,
    reason: reason,
  );
}
