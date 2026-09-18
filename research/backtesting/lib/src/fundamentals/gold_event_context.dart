enum GoldEventRisk { normal, caution, highRisk }

final class GoldEconomicEvent {
  const GoldEconomicEvent({
    required this.id,
    required this.name,
    required this.scheduledAtUtc,
    required this.impact,
    required this.category,
    this.consensus,
    this.prior,
    this.actual,
    this.sourceUrl,
  });

  final String id;
  final String name;
  final DateTime scheduledAtUtc;
  final String impact;
  final String category;
  final String? consensus;
  final String? prior;
  final String? actual;
  final String? sourceUrl;

  bool get isHighImpact => impact.toLowerCase() == 'high';
}

final class GoldEventContext {
  const GoldEventContext({
    required this.observedAtUtc,
    required this.events,
    required this.risk,
    required this.source,
  });

  final DateTime observedAtUtc;
  final List<GoldEconomicEvent> events;
  final GoldEventRisk risk;
  final String source;

  bool get hasHighImpactEvent => events.any((event) => event.isHighImpact);
}
