import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/fundamentals/ai_review_context_audit.dart';

void main() {
  test(
    'complete candidate still reports missing market context separately',
    () {
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
        },
        economicCalendar: {'source': 'finance_calendar', 'events': <Object?>[]},
        newsContext: {'availability': 'available', 'items': <Object?>[]},
      );

      expect(audit.candidateCoreComplete, isTrue);
      expect(audit.missingCandidateFields, isEmpty);
      expect(audit.newsAvailable, isTrue);
      expect(audit.calendarAvailable, isTrue);
      expect(audit.marketContextAvailable, isFalse);
      expect(audit.coverage, 'PARTIAL');
    },
  );

  test(
    'missing candidate fields are reported but never expressed as a gate',
    () {
      final audit = auditAiReviewContext(
        candidate: const {'strategy': 'C5', 'side': 'BUY'},
        economicCalendar: const {'source': 'finance_calendar_unavailable'},
        newsContext: const {'availability': 'unavailable'},
      );

      expect(audit.candidateCoreComplete, isFalse);
      expect(audit.missingCandidateFields, contains('entry'));
      expect(audit.missingCandidateFields, contains('stopLoss'));
      expect(audit.missingCandidateFields, contains('takeProfit'));
      expect(audit.coverage, 'LIMITED');
    },
  );

  test('market context is recognized only when explicitly supplied', () {
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
          'timeframes': {
            'M5': {'available': true},
          },
        },
      },
      economicCalendar: const {'source': 'finance_calendar'},
      newsContext: const {'availability': 'available'},
    );

    expect(audit.marketContextAvailable, isTrue);
    expect(audit.coverage, 'FULL');
  });
}
