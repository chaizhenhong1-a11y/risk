import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_candle.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_engine.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_session.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';

void main() {
  test('runs update and produces cumulative forward statistics', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-session-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final signals = File('${dir.path}${Platform.pathSeparator}signals.jsonl');
    final results = File('${dir.path}${Platform.pathSeparator}results.jsonl');

    const engine = PaperForwardEngine();
    engine.record(
      journalFile: signals,
      symbol: 'XAUUSD',
      strategy: 'A',
      side: PaperSignalSide.buy,
      observedAt: DateTime.utc(2026, 9, 17, 8),
      entry: 3600,
      stopLoss: 3590,
      takeProfit: 3620,
      reason: 'A',
    );
    engine.record(
      journalFile: signals,
      symbol: 'XAUUSD',
      strategy: 'C5',
      side: PaperSignalSide.buy,
      observedAt: DateTime.utc(2026, 9, 17, 8),
      entry: 3600,
      stopLoss: 3590,
      takeProfit: 3620,
      reason: 'C5',
    );

    final report = const PaperForwardSession().run(
      signalsFile: signals,
      resultsFile: results,
      newCandles: [
        PaperCandle(
          closeTime: DateTime.utc(2026, 9, 17, 8, 5),
          open: 3600,
          high: 3621,
          low: 3595,
          close: 3618,
        ),
      ],
    );

    expect(report.signals, 2);
    expect(report.resolved, 2);
    expect(report.wins, 2);
    expect(report.losses, 0);
    expect(report.grossR, 4);
    expect(report.expectancyR, 2);
  });
}
