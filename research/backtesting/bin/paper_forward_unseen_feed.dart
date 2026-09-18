import 'dart:io';

import 'package:tradeforge_backtesting/src/forward/paper_forward_checkpoint.dart';
import 'package:tradeforge_backtesting/src/forward/paper_mt5_history_adapter.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run bin/paper_forward_unseen_feed.dart '
      '<XAUUSD_M5.csv> [checkpoint.json]',
    );
    exitCode = 64;
    return;
  }

  final candles = const PaperMt5HistoryAdapter().readM5(File(arguments[0]));
  final checkpointFile = File(
    arguments.length == 2
        ? arguments[1]
        : '.research_cache${Platform.pathSeparator}paper_forward'
              '${Platform.pathSeparator}checkpoint.json',
  );
  const checkpoint = PaperForwardCheckpoint();
  final lastSeen = checkpoint.read(checkpointFile);
  final unseen = candles
      .where((candle) => lastSeen == null || candle.closeTime.isAfter(lastSeen))
      .toList();

  stdout.writeln('TradeForge V2 — Unseen MT5 Feed Boundary');
  stdout.writeln('Closed M5 candles loaded: ${candles.length}');
  stdout.writeln('Previous checkpoint: ${lastSeen ?? 'none'}');
  stdout.writeln('Unseen closed candles: ${unseen.length}');

  if (unseen.isNotEmpty) {
    stdout.writeln('First unseen: ${unseen.first.closeTime}');
    stdout.writeln('Last unseen: ${unseen.last.closeTime}');
    stdout.writeln('');
    stdout.writeln(
      'Checkpoint is NOT advanced by this inspection command. '
      'The paper live cycle advances it only after A/C5 detection and '
      'journal/lifecycle persistence succeed.',
    );
  }
}
