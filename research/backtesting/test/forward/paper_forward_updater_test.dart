import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_candle.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_engine.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_updater.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_trade_result_journal.dart';

void main() {
  late Directory temp;
  late File signals;
  late File results;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('tradeforge-updater-');
    signals = File('${temp.path}${Platform.pathSeparator}signals.jsonl');
    results = File('${temp.path}${Platform.pathSeparator}results.jsonl');

    const PaperForwardEngine().record(
      journalFile: signals,
      symbol: 'XAUUSD',
      strategy: 'A',
      side: PaperSignalSide.buy,
      observedAt: DateTime.utc(2026, 9, 17, 8),
      entry: 3600,
      stopLoss: 3590,
      takeProfit: 3620,
      reason: 'A paper opportunity',
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('new M5 candle resolves pending signal and persists result', () {
    final report = const PaperForwardUpdater().update(
      signalsFile: signals,
      resultsFile: results,
      candles: [
        PaperCandle(
          closeTime: DateTime.utc(2026, 9, 17, 8, 5),
          open: 3600,
          high: 3621,
          low: 3595,
          close: 3618,
        ),
      ],
    );

    expect(report.newlyResolved, 1);
    final stored = const PaperTradeResultJournal().readAll(results);
    expect(stored.single.status, PaperSignalStatus.targetHit);
    expect(stored.single.grossR, 2);
  });

  test('rerun is idempotent', () {
    const updater = PaperForwardUpdater();
    final candles = [
      PaperCandle(
        closeTime: DateTime.utc(2026, 9, 17, 8, 5),
        open: 3600,
        high: 3621,
        low: 3595,
        close: 3618,
      ),
    ];

    updater.update(
      signalsFile: signals,
      resultsFile: results,
      candles: candles,
    );
    final second = updater.update(
      signalsFile: signals,
      resultsFile: results,
      candles: candles,
    );

    expect(second.newlyResolved, 0);
    expect(second.alreadyResolved, 1);
  });
}
