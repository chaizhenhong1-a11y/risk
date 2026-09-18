import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_strategy_detector.dart';
import 'package:tradeforge_backtesting/src/forward/paper_candle.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_checkpoint.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_live_cycle.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal_journal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_strategy_opportunity.dart';

void main() {
  PaperCandle candle(int minute) => PaperCandle(
    closeTime: DateTime(2026, 9, 17, 8, minute),
    open: 3600,
    high: 3610,
    low: 3590,
    close: 3600,
  );

  PaperStrategyOpportunity opportunity(String strategy, DateTime time) =>
      PaperStrategyOpportunity(
        symbol: 'XAUUSD',
        strategy: strategy,
        side: PaperSignalSide.buy,
        observedAt: time,
        entry: 3600,
        stopLoss: 3590,
        takeProfit: 3620,
        reason: 'frozen $strategy test opportunity',
      );

  test(
    'immutable start excludes old observations but keeps history visible',
    () {
      final dir = Directory.systemTemp.createTempSync('tradeforge-157-start-');
      addTearDown(() => dir.deleteSync(recursive: true));

      final seenLengths = <int>[];
      final detector = FrozenStrategyDetector(
        strategy: 'A',
        evaluate: (candles) {
          seenLengths.add(candles.length);
          return null;
        },
      );

      final report = const PaperForwardLiveCycle().run(
        allClosedCandles: [candle(0), candle(5), candle(10)],
        detectors: [detector],
        signalsFile: File('${dir.path}/signals.jsonl'),
        resultsFile: File('${dir.path}/results.jsonl'),
        checkpointFile: File('${dir.path}/checkpoint.json'),
        startStateFile: File('${dir.path}/start.json'),
        requestedStartAt: candle(5).closeTime,
      );

      expect(report.unseenCandles, 1);
      expect(seenLengths, [3]);
    },
  );

  test('restart plus deterministic journal dedupe cannot duplicate A/C5', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-157-dedupe-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final signals = File('${dir.path}/signals.jsonl');
    final results = File('${dir.path}/results.jsonl');
    final checkpoint = File('${dir.path}/checkpoint.json');
    final start = File('${dir.path}/start.json');
    final candles = [candle(0), candle(5)];

    final detectors = [
      FrozenStrategyDetector(
        strategy: 'A',
        evaluate: (visible) => visible.length == 2
            ? opportunity('A', visible.last.closeTime)
            : null,
      ),
      FrozenStrategyDetector(
        strategy: 'C5',
        evaluate: (visible) => visible.length == 2
            ? opportunity('C5', visible.last.closeTime)
            : null,
      ),
    ];

    final first = const PaperForwardLiveCycle().run(
      allClosedCandles: candles,
      detectors: detectors,
      signalsFile: signals,
      resultsFile: results,
      checkpointFile: checkpoint,
      startStateFile: start,
      requestedStartAt: candle(0).closeTime,
    );
    final second = const PaperForwardLiveCycle().run(
      allClosedCandles: candles,
      detectors: detectors,
      signalsFile: signals,
      resultsFile: results,
      checkpointFile: checkpoint,
      startStateFile: start,
      requestedStartAt: DateTime(2020),
    );

    expect(first.recorded, 2);
    expect(second.unseenCandles, 0);
    expect(const PaperSignalJournal().readAll(signals), hasLength(2));
  });

  test('A and C5 are persisted as already-triggered paper trades', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-157-active-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final signals = File('${dir.path}/signals.jsonl');
    final results = File('${dir.path}/results.jsonl');

    final detectors = [
      FrozenStrategyDetector(
        strategy: 'A',
        evaluate: (visible) => opportunity('A', visible.last.closeTime),
      ),
      FrozenStrategyDetector(
        strategy: 'C5',
        evaluate: (visible) => opportunity('C5', visible.last.closeTime),
      ),
    ];

    const PaperForwardLiveCycle().run(
      allClosedCandles: [candle(5)],
      detectors: detectors,
      signalsFile: signals,
      resultsFile: results,
      checkpointFile: File('${dir.path}/checkpoint.json'),
    );

    final stored = const PaperSignalJournal().readAll(signals);
    expect(
      stored.map((s) => s.status),
      everyElement(PaperSignalStatus.triggered),
    );
  });

  test('checkpoint preserves timezone-unspecified MT5 wall clock', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-157-time-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/checkpoint.json');
    final sourceTime = DateTime(2026, 9, 17, 8, 5);

    const PaperForwardCheckpoint().write(file, sourceTime);
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    expect(json['lastClosedCandle'], sourceTime.toIso8601String());
    expect(const PaperForwardCheckpoint().read(file), sourceTime);
    expect(const PaperForwardCheckpoint().read(file)!.isUtc, isFalse);
  });
}
