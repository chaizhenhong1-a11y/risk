import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_strategy_detector.dart';
import 'package:tradeforge_backtesting/src/forward/paper_candle.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_checkpoint.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_live_cycle.dart';

void main() {
  test('detector never sees future candles and checkpoint advances', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-live-cycle-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final signals = File('${dir.path}${Platform.pathSeparator}signals.jsonl');
    final results = File('${dir.path}${Platform.pathSeparator}results.jsonl');
    final checkpointFile = File(
      '${dir.path}${Platform.pathSeparator}checkpoint.json',
    );

    final seenLengths = <int>[];
    final detector = FrozenStrategyDetector(
      strategy: 'A',
      evaluate: (candles) {
        seenLengths.add(candles.length);
        return null;
      },
    );

    final candles = [
      PaperCandle(
        closeTime: DateTime.utc(2026, 9, 17, 8),
        open: 1,
        high: 1,
        low: 1,
        close: 1,
      ),
      PaperCandle(
        closeTime: DateTime.utc(2026, 9, 17, 8, 5),
        open: 1,
        high: 1,
        low: 1,
        close: 1,
      ),
    ];

    final report = const PaperForwardLiveCycle().run(
      allClosedCandles: candles,
      detectors: [detector],
      signalsFile: signals,
      resultsFile: results,
      checkpointFile: checkpointFile,
    );

    expect(seenLengths, [1, 2]);
    expect(report.unseenCandles, 2);
    expect(report.checkpointAdvanced, isTrue);
    expect(
      const PaperForwardCheckpoint().read(checkpointFile),
      candles.last.closeTime,
    );
  });

  test('existing checkpoint processes only genuinely unseen candles', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-unseen-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final checkpointFile = File(
      '${dir.path}${Platform.pathSeparator}checkpoint.json',
    );
    final first = DateTime.utc(2026, 9, 17, 8);
    const PaperForwardCheckpoint().write(checkpointFile, first);

    var calls = 0;
    final detector = FrozenStrategyDetector(
      strategy: 'C5',
      evaluate: (_) {
        calls++;
        return null;
      },
    );

    final report = const PaperForwardLiveCycle().run(
      allClosedCandles: [
        PaperCandle(closeTime: first, open: 1, high: 1, low: 1, close: 1),
        PaperCandle(
          closeTime: DateTime.utc(2026, 9, 17, 8, 5),
          open: 1,
          high: 1,
          low: 1,
          close: 1,
        ),
      ],
      detectors: [detector],
      signalsFile: File('${dir.path}${Platform.pathSeparator}signals.jsonl'),
      resultsFile: File('${dir.path}${Platform.pathSeparator}results.jsonl'),
      checkpointFile: checkpointFile,
    );

    expect(report.unseenCandles, 1);
    expect(calls, 1);
  });
}
