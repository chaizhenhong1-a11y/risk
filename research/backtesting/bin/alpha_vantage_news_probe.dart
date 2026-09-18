import 'package:tradeforge_backtesting/src/fundamentals/alpha_vantage_news_client.dart';

Future<void> main() async {
  final context = await AlphaVantageNewsClient().loadGoldNews(
    nowUtc: DateTime.now().toUtc(),
  );

  print({
    'provider': context.provider,
    'availability': context.availability.name,
    'reason': context.reason,
    'observedAtUtc': context.observedAtUtc.toIso8601String(),
    'newsCount': context.items.length,
    'news': context.items
        .take(10)
        .map(
          (item) => {
            'publishedAtUtc': item.publishedAtUtc.toIso8601String(),
            'source': item.source,
            'title': item.title,
            'topics': item.topics,
            'sentiment': item.overallSentimentScore,
            'url': item.url,
          },
        )
        .toList(growable: false),
  });
}
