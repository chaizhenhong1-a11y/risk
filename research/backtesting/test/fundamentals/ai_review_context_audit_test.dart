import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/fundamentals/ai_review_context_audit.dart';

void main() {
  final now = DateTime.utc(2026, 9, 19, 12);

  test('complete candidate reports context coverage and fresh ages', () {
    final audit = auditAiReviewContext(
      candidate: {
        'strategy': 'C5',
        'side': 'BUY',
        'entry': 3700.0,
        'stopLoss': 3690.0,
        'takeProfit': 3720.0,
        'riskReward': 2.0,
        'reason': 'frozen trigger',
        'exposureStatus': 'independent',
        'marketContext': {
          'observedAt': now
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
        },
      },
      economicCalendar: {
        'observedAtUtc': now
            .subtract(const Duration(minutes: 5))
            .toIso8601String(),
        'source': 'finance_calendar',
      },
      newsContext: {
        'observedAtUtc': now
            .subtract(const Duration(minutes: 20))
            .toIso8601String(),
        'availability': 'available',
      },
      referenceTimeUtc: now,
    );

    expect(audit.coverage, 'FULL');
    expect(audit.newsAgeMinutes, 20);
    expect(audit.calendarAgeMinutes, 5);
    expect(audit.marketAgeMinutes, 5);
    expect(audit.hasStaleContext, isFalse);
  });

  test('stale context is reported but never expressed as a gate', () {
    final audit = auditAiReviewContext(
      candidate: {
        'strategy': 'A',
        'side': 'SELL',
        'entry': 3700.0,
        'stopLoss': 3710.0,
        'takeProfit': 3680.0,
        'riskReward': 2.0,
        'reason': 'trigger',
        'exposureStatus': 'independent',
        'marketContext': {
          'observedAt': now
              .subtract(const Duration(minutes: 11))
              .toIso8601String(),
        },
      },
      economicCalendar: {
        'observedAtUtc': now
            .subtract(const Duration(minutes: 16))
            .toIso8601String(),
        'source': 'finance_calendar',
      },
      newsContext: {
        'observedAtUtc': now
            .subtract(const Duration(minutes: 46))
            .toIso8601String(),
        'availability': 'available',
      },
      referenceTimeUtc: now,
    );

    expect(audit.newsStale, isTrue);
    expect(audit.calendarStale, isTrue);
    expect(audit.marketStale, isTrue);
    expect(audit.hasStaleContext, isTrue);
    expect(audit.coverage, 'FULL');
  });

  test('missing candidate fields remain LIMITED without becoming a gate', () {
    final audit = auditAiReviewContext(
      candidate: const {'strategy': 'C5', 'side': 'BUY'},
      economicCalendar: const {'source': 'finance_calendar_unavailable'},
      newsContext: const {'availability': 'unavailable'},
      referenceTimeUtc: now,
    );

    expect(audit.candidateCoreComplete, isFalse);
    expect(audit.missingCandidateFields, contains('entry'));
    expect(audit.coverage, 'LIMITED');
  });
}
