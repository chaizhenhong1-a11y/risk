import 'package:tradeforge_backtesting/src/fundamentals/gemini_fundamental_review_client.dart';

Future<void> main() async {
  final now = DateTime.now().toUtc();
  final review = await GeminiFundamentalReviewClient().review(
    candidate: {
      'symbol': 'XAUUSD',
      'strategy': 'C5',
      'side': 'BUY',
      'note': 'Probe only; no execution decision requested.',
    },
    economicCalendar: {
      'source': 'financecalendar.com',
      'events': [
        {
          'name': 'US CPI',
          'scheduledAtUtc': now
              .add(const Duration(minutes: 20))
              .toIso8601String(),
          'impact': 'high',
        },
      ],
    },
    newsContext: {
      'provider': 'alpha_vantage',
      'items': [
        {
          'title': 'Fed policy outlook moves markets',
          'publishedAtUtc': now
              .subtract(const Duration(minutes: 30))
              .toIso8601String(),
          'summary':
              'Treasury yields and the dollar moved after policy commentary.',
        },
      ],
    },
  );
  print({
    'available': review.available,
    'model': review.model,
    'risk': review.risk.name,
    'goldBias': review.goldBias,
    'summary': review.summary,
    'relevantFactors': review.relevantFactors,
    'reason': review.reason,
    'candidatePreserved': true,
  });
}
