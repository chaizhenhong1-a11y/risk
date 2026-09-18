import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/fundamentals/finance_calendar_client.dart';

final class _ShapeTransport implements FinanceCalendarTransport {
  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required Duration timeout,
  }) async {
    return {
      'events': [
        {
          'name': 'US Employment Situation (Non-Farm Payrolls)',
          'time_utc': '2026-08-07T12:30:00+00:00',
          'impact': 'high',
          'category': 'economic-indicators',
          'consensus': '100K',
          'prior': '90K',
          'actual': '110K',
          'url': 'https://www.financecalendar.com/',
        },
        {
          'name': 'US CPI Report',
          'time_utc': '2026-08-12T12:30:00+00:00',
          'impact': 'high',
          'category': 'economic-indicators',
        },
      ],
    };
  }
}

void main() {
  test(
    'documented Finance Calendar event shape parses into gold context',
    () async {
      final context = await FinanceCalendarClient(transport: _ShapeTransport())
          .loadGoldContext(
            nowUtc: DateTime.utc(2026, 8, 1),
            lookAhead: const Duration(days: 30),
          );

      expect(context.events, hasLength(2));
      expect(context.events.first.name, contains('Non-Farm Payrolls'));
      expect(context.events.first.actual, '110K');
      expect(context.events.last.name, contains('CPI'));
    },
  );
}
