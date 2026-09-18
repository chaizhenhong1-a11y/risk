enum GoldNewsAvailability { available, unavailable }

final class GoldNewsItem {
  const GoldNewsItem({
    required this.title,
    required this.publishedAtUtc,
    required this.source,
    required this.url,
    required this.summary,
    required this.topics,
    required this.overallSentimentScore,
  });

  final String title;
  final DateTime publishedAtUtc;
  final String source;
  final String url;
  final String summary;
  final List<String> topics;
  final double? overallSentimentScore;
}

final class GoldNewsContext {
  const GoldNewsContext({
    required this.observedAtUtc,
    required this.items,
    required this.availability,
    required this.provider,
    this.reason,
  });

  final DateTime observedAtUtc;
  final List<GoldNewsItem> items;
  final GoldNewsAvailability availability;
  final String provider;
  final String? reason;

  bool get isAvailable => availability == GoldNewsAvailability.available;
}
