import 'package:tradeforge_backtesting/src/fundamentals/finance_calendar_client.dart';

Future<void> main(List<String> args) async {
  final client = FinanceCalendarClient();
  final now = DateTime.now().toUtc();

  print('=== Finance Calendar integrity probe ===');
  print('nowUtc: ${now.toIso8601String()}');

  final windows = <({String label, DateTime from, Duration lookAhead})>[
    (label: 'next_24h', from: now, lookAhead: const Duration(hours: 24)),
    (label: 'next_14d', from: now, lookAhead: const Duration(days: 14)),
    (
      label: 'known_historical_window',
      from: DateTime.utc(2026, 8, 1),
      lookAhead: const Duration(days: 30),
    ),
  ];

  var historicalVerified = false;
  for (final window in windows) {
    try {
      final context = await client.loadGoldContext(
        nowUtc: window.from,
        lookAhead: window.lookAhead,
      );
      print({
        'window': window.label,
        'fromUtc': window.from.toIso8601String(),
        'risk': context.risk.name,
        'eventCount': context.events.length,
        'events': context.events
            .take(20)
            .map(
              (event) => {
                'name': event.name,
                'scheduledAtUtc': event.scheduledAtUtc.toIso8601String(),
                'impact': event.impact,
                'category': event.category,
                'consensus': event.consensus,
                'prior': event.prior,
                'actual': event.actual,
              },
            )
            .toList(growable: false),
      });
      if (window.label == 'known_historical_window') {
        historicalVerified = context.events.isNotEmpty;
      }
    } catch (error) {
      print({
        'window': window.label,
        'status': 'unavailable',
        'error': '$error',
      });
    }
  }

  print({
    'integrity': historicalVerified ? 'VERIFIED_NON_EMPTY' : 'NOT_VERIFIED',
    'note': historicalVerified
        ? 'Parser and calendar endpoint returned known historical high-impact data.'
        : 'Do not trust empty live windows until provider/schema is verified.',
  });
}
