import 'dart:io';

import 'package:tradeforge_backtesting/src/forward/biquote_feed_guard.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_rest_client.dart';

Future<void> main() async {
  final client = BiQuoteRestClient();
  try {
    final tick = await client.latestTick('XAUUSD');
    final health = const BiQuoteTickGuard().evaluate(tick);

    stdout.writeln('TradeForge V2 — BiQuote XAUUSD Probe');
    stdout.writeln('symbol=${tick.symbol}');
    stdout.writeln('bid=${tick.bid} ask=${tick.ask} mid=${tick.mid}');
    stdout.writeln('timestamp=${tick.timestamp.toIso8601String()}');
    stdout.writeln('nativeTime=${tick.nativeTime.toIso8601String()}');
    stdout.writeln('source=${tick.source}');
    stdout.writeln(
      'marketState=${tick.marketState} stale=${tick.stale} '
      'quoteAgeSeconds=${tick.quoteAgeSeconds}',
    );
    stdout.writeln('health=${health.name}');

    for (final timeframe in BiQuoteTimeframe.values) {
      final response = await client.closedBars(
        symbol: 'XAUUSD',
        timeframe: timeframe,
        limit: 5,
      );
      final last = response.closedBars.isEmpty
          ? null
          : response.closedBars.last;
      stdout.writeln(
        '${timeframe.apiValue}: closed=${response.closedBars.length} '
        'openIgnored=${response.openBars} '
        'lastClosed=${last?.closeTime.toIso8601String() ?? 'none'}',
      );
    }
  } finally {
    client.close();
  }
}
