import 'dart:async';
import 'dart:io';

import 'package:tradeforge_backtesting/src/forward/biquote_realtime_feed.dart';

Future<void> main(List<String> arguments) async {
  final seconds = arguments.isEmpty ? 20 : int.parse(arguments.first);
  final feed = BiQuoteRealtimeFeed();
  var ticks = 0;

  stdout.writeln('TradeForge V2 — BiQuote XAUUSD SignalR');
  stdout.writeln('Listening for $seconds seconds...');

  final stateSub = feed.states.listen(
    (state) => stdout.writeln('stream=${state.name}'),
  );
  final diagnosticSub = feed.diagnostics.listen(
    (event) => stdout.writeln('diag: $event'),
  );
  final tickSub = feed.ticks.listen((tick) {
    ticks++;
    stdout.writeln(
      '#$ticks ${tick.timestamp.toIso8601String()} '
      'bid=${tick.bid} ask=${tick.ask} mid=${tick.mid}',
    );
  });

  try {
    final bootstrap = await feed.start(warmupPerTimeframe: 100);
    stdout.writeln(
      'bootstrap added=${bootstrap.addedClosedBars} '
      'duplicates=${bootstrap.duplicates} '
      'openIgnored=${bootstrap.ignoredOpenBars}',
    );
    await Future<void>.delayed(Duration(seconds: seconds));
  } finally {
    await tickSub.cancel();
    await diagnosticSub.cancel();
    await stateSub.cancel();
    await feed.dispose();
  }

  stdout.writeln('received=$ticks healthy XAUUSD ticks');
}
