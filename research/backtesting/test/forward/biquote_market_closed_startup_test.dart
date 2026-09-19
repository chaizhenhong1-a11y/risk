import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('market-closed startup is explicitly fail-safe', () {
    final root = Directory.current.path.endsWith('backtesting')
        ? Directory.current
        : Directory('research/backtesting');
    final rest = File(
      '${root.path}/lib/src/forward/biquote_rest_client.dart',
    ).readAsStringSync();
    final feed = File(
      '${root.path}/lib/src/forward/biquote_realtime_feed.dart',
    ).readAsStringSync();

    expect(rest, contains('latestTickOrNull'));
    expect(rest, contains('No tick data available'));
    expect(feed, contains('latestTickOrNull(symbol)'));
    expect(feed, contains('if (restHealthy)'));
    expect(feed, contains('await streamClient.start();'));
    expect(feed, contains('BiQuoteBootstrap().load'));
  });
}
