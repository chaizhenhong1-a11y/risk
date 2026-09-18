import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/fundamentals/finance_calendar_client.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gold_event_context.dart';

final class _FakeTransport implements FinanceCalendarTransport {
  _FakeTransport(this.response);
  final Map<String, dynamic> response;
  Uri? requestedUri;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required Duration timeout,
  }) async {
    requestedUri = uri;
    return response;
  }
}

void main() {
  test('high-impact event within 30 minutes is context, not a gate', () async {
    final transport = _FakeTransport({
      'events': [
        {
          'id': 'cpi',
          'name': 'US CPI',
          'time_utc': '2026-09-18T12:20:00+00:00',
          'impact': 'high',
          'category': 'inflation',
          'consensus': '2.8%',
          'prior': '3.0%',
        },
      ],
    });
    final client = FinanceCalendarClient(transport: transport);
    final context = await client.loadGoldContext(
      nowUtc: DateTime.parse('2026-09-18T12:00:00Z'),
    );

    expect(context.risk, GoldEventRisk.highRisk);
    expect(context.events.single.name, 'US CPI');
    expect(context.events.single.consensus, '2.8%');
    expect(transport.requestedUri!.queryParameters['impact'], 'high');
  });

  test('far event remains normal', () async {
    final client = FinanceCalendarClient(
      transport: _FakeTransport({
        'events': [
          {
            'id': 'fomc',
            'name': 'FOMC',
            'time_utc': '2026-09-18T20:00:00+00:00',
            'impact': 'high',
            'category': 'central-bank',
          },
        ],
      }),
    );
    final context = await client.loadGoldContext(
      nowUtc: DateTime.parse('2026-09-18T12:00:00Z'),
    );
    expect(context.risk, GoldEventRisk.normal);
  });
}
