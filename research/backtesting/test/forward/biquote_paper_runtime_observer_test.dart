import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_live_market_snapshot.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_paper_runtime_observer.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_segment_paper_lifecycle.dart';

void main() {
  test(
    'runtime observer reports every CLOSED M5 without mutating evidence',
    () async {
      final dir = await Directory.systemTemp.createTemp('runtime_observer_');
      addTearDown(() => dir.delete(recursive: true));
      final candidates = File('${dir.path}/candidates.jsonl');
      await candidates.writeAsString('{"candidate":1}\n{"candidate":2}\n');

      final lifecycle = BiQuoteSegmentPaperLifecycle(
        candidateJournal: File('${dir.path}/empty_candidates.jsonl'),
        stateFile: File('${dir.path}/state.json'),
        resultJournal: File('${dir.path}/results.jsonl'),
      );
      final sinkFile = File('${dir.path}/console.txt');
      final sink = sinkFile.openWrite();
      final observer = BiQuotePaperRuntimeObserver(
        segmentCandidateJournal: candidates,
        segmentLifecycle: lifecycle,
        output: sink,
      );

      final result = await observer.onClosedM5(_snapshot());
      await sink.flush();
      await sink.close();

      expect(result.closedM5Count, 1);
      expect(result.segmentCandidates, 2);
      expect(result.segmentStats.total, 0);
      final output = await sinkFile.readAsString();
      expect(output, contains('[LIVE] CLOSED M5 #1'));
      expect(output, contains('segment candidates=2'));
    },
  );
}

BiQuoteLiveMarketSnapshot _snapshot() {
  final bar = BiQuoteClosedBar(
    symbol: 'XAUUSD',
    timeframe: BiQuoteTimeframe.m5,
    openTime: DateTime.utc(2026, 9, 18, 2, 40),
    open: 3660,
    high: 3662,
    low: 3659,
    close: 3661,
    tickVolume: 1,
  );
  return BiQuoteLiveMarketSnapshot(
    observedAt: bar.closeTime,
    m5: <BiQuoteClosedBar>[bar],
    m15: <BiQuoteClosedBar>[bar],
    h1: <BiQuoteClosedBar>[bar],
    h4: <BiQuoteClosedBar>[bar],
  );
}
