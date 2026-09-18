import 'gold_event_context.dart';
import 'gold_news_context.dart';
import 'gemini_fundamental_review.dart';

typedef GoldNewsLoader = Future<GoldNewsContext> Function(DateTime nowUtc);
typedef GoldEventLoader = Future<GoldEventContext> Function(DateTime nowUtc);
typedef FundamentalReviewer =
    Future<GeminiFundamentalReview> Function(
      Map<String, dynamic> candidate,
      Map<String, dynamic> economicCalendar,
      Map<String, dynamic> newsContext,
    );

final class FundamentalReviewResult {
  const FundamentalReviewResult({
    required this.review,
    required this.newsContext,
    required this.eventContext,
    required this.newsCacheHit,
    required this.calendarCacheHit,
    required this.candidatePreserved,
  });

  final GeminiFundamentalReview review;
  final GoldNewsContext newsContext;
  final GoldEventContext eventContext;
  final bool newsCacheHit;
  final bool calendarCacheHit;

  /// Fundamental/news review is advisory. It never deletes the strategy candidate.
  final bool candidatePreserved;
}

/// Candidate-triggered fundamental context with bounded provider usage.
///
/// A candidate may cause a provider refresh only when the corresponding cache
/// is missing or stale. Multiple candidates inside the TTL reuse the same
/// snapshot. Provider/reviewer failures are fail-open and never invalidate the
/// strategy candidate.
final class CandidateFundamentalReviewService {
  CandidateFundamentalReviewService({
    required GoldNewsLoader loadNews,
    required GoldEventLoader loadEvents,
    required FundamentalReviewer review,
    this.newsTtl = const Duration(minutes: 45),
    this.calendarTtl = const Duration(minutes: 15),
  }) : _loadNews = loadNews,
       _loadEvents = loadEvents,
       _review = review;

  final GoldNewsLoader _loadNews;
  final GoldEventLoader _loadEvents;
  final FundamentalReviewer _review;
  final Duration newsTtl;
  final Duration calendarTtl;

  GoldNewsContext? _newsCache;
  GoldEventContext? _eventCache;

  Future<FundamentalReviewResult> reviewIndependentCandidate({
    required Map<String, dynamic> candidate,
    required DateTime nowUtc,
  }) async {
    final now = nowUtc.toUtc();

    final newsWasFresh = _isNewsFresh(now);
    final news = newsWasFresh ? _newsCache! : await _refreshNews(now);

    final calendarWasFresh = _isCalendarFresh(now);
    final events = calendarWasFresh ? _eventCache! : await _refreshEvents(now);

    GeminiFundamentalReview aiReview;
    try {
      aiReview = await _review(
        Map<String, dynamic>.unmodifiable(candidate),
        _eventJson(events),
        _newsJson(news),
      );
    } catch (error) {
      aiReview = GeminiFundamentalReview.unavailable(
        model: 'unavailable',
        reason: 'Fundamental reviewer failure: $error',
      );
    }

    return FundamentalReviewResult(
      review: aiReview,
      newsContext: news,
      eventContext: events,
      newsCacheHit: newsWasFresh,
      calendarCacheHit: calendarWasFresh,
      candidatePreserved: true,
    );
  }

  bool _isNewsFresh(DateTime now) {
    final cached = _newsCache;
    if (cached == null) return false;
    return now.difference(cached.observedAtUtc.toUtc()) < newsTtl;
  }

  bool _isCalendarFresh(DateTime now) {
    final cached = _eventCache;
    if (cached == null) return false;
    return now.difference(cached.observedAtUtc.toUtc()) < calendarTtl;
  }

  Future<GoldNewsContext> _refreshNews(DateTime now) async {
    try {
      final loaded = await _loadNews(now);
      _newsCache = loaded;
      return loaded;
    } catch (error) {
      final stale = _newsCache;
      if (stale != null) return stale;
      final unavailable = GoldNewsContext(
        observedAtUtc: now,
        items: const [],
        availability: GoldNewsAvailability.unavailable,
        provider: 'alpha_vantage',
        reason: 'News refresh failed: $error',
      );
      _newsCache = unavailable;
      return unavailable;
    }
  }

  Future<GoldEventContext> _refreshEvents(DateTime now) async {
    try {
      final loaded = await _loadEvents(now);
      _eventCache = loaded;
      return loaded;
    } catch (_) {
      final stale = _eventCache;
      if (stale != null) return stale;
      final unavailable = GoldEventContext(
        observedAtUtc: now,
        events: const [],
        risk: GoldEventRisk.normal,
        source: 'finance_calendar_unavailable',
      );
      _eventCache = unavailable;
      return unavailable;
    }
  }

  Map<String, dynamic> _eventJson(GoldEventContext context) {
    return {
      'observedAtUtc': context.observedAtUtc.toIso8601String(),
      'risk': context.risk.name,
      'source': context.source,
      'events': [
        for (final event in context.events)
          {
            'id': event.id,
            'name': event.name,
            'scheduledAtUtc': event.scheduledAtUtc.toIso8601String(),
            'impact': event.impact,
            'category': event.category,
            'consensus': event.consensus,
            'prior': event.prior,
            'actual': event.actual,
          },
      ],
    };
  }

  Map<String, dynamic> _newsJson(GoldNewsContext context) {
    return {
      'observedAtUtc': context.observedAtUtc.toIso8601String(),
      'availability': context.availability.name,
      'provider': context.provider,
      'reason': context.reason,
      'items': [
        for (final item in context.items)
          {
            'title': item.title,
            'publishedAtUtc': item.publishedAtUtc.toIso8601String(),
            'source': item.source,
            'summary': item.summary,
            'topics': item.topics,
            'overallSentimentScore': item.overallSentimentScore,
          },
      ],
    };
  }
}
