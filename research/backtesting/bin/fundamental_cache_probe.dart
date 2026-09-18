import 'package:tradeforge_backtesting/src/forward/tradeforge_env.dart';
import 'package:tradeforge_backtesting/src/fundamentals/alpha_vantage_news_client.dart';
import 'package:tradeforge_backtesting/src/fundamentals/candidate_fundamental_review_service.dart';
import 'package:tradeforge_backtesting/src/fundamentals/finance_calendar_client.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gemini_fundamental_review_client.dart';

Future<void> main() async {
  final env = TradeForgeEnv.load();
  final newsClient = AlphaVantageNewsClient();
  final calendarClient = FinanceCalendarClient();
  final gemini = GeminiFundamentalReviewClient();

  final service = CandidateFundamentalReviewService(
    loadNews: (now) => newsClient.loadGoldNews(nowUtc: now),
    loadEvents: (now) => calendarClient.loadGoldContext(nowUtc: now),
    review: (candidate, calendar, news) => gemini.review(
      candidate: candidate,
      economicCalendar: calendar,
      newsContext: news,
    ),
  );

  final now = DateTime.now().toUtc();
  final first = await service.reviewIndependentCandidate(
    candidate: const {
      'strategy': 'C5',
      'side': 'BUY',
      'symbol': 'XAUUSD',
      'independentEvidence': true,
    },
    nowUtc: now,
  );
  final second = await service.reviewIndependentCandidate(
    candidate: const {
      'strategy': 'NR7_BREAKOUT',
      'side': 'SELL',
      'symbol': 'XAUUSD',
      'independentEvidence': true,
    },
    nowUtc: now.add(const Duration(minutes: 1)),
  );

  print({
    'alphaVantageConfigured': (env['ALPHA_VANTAGE_API_KEY'] ?? '')
        .trim()
        .isNotEmpty,
    'first': {
      'newsCacheHit': first.newsCacheHit,
      'calendarCacheHit': first.calendarCacheHit,
      'risk': first.review.risk.name,
      'aiAvailable': first.review.available,
      'candidatePreserved': first.candidatePreserved,
    },
    'second': {
      'newsCacheHit': second.newsCacheHit,
      'calendarCacheHit': second.calendarCacheHit,
      'risk': second.review.risk.name,
      'aiAvailable': second.review.available,
      'candidatePreserved': second.candidatePreserved,
    },
  });
}
