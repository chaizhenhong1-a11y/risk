import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_live_market_snapshot.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_segment_paper_lifecycle.dart';

void main() {
  test('segment lifecycle never resolves on the signal candle', () async {
    final dir = await Directory.systemTemp.createTemp('segment_lifecycle_');
    addTearDown(() => dir.delete(recursive: true));

    final candidates = File('${dir.path}/candidates.jsonl');
    final state = File('${dir.path}/state.json');
    final results = File('${dir.path}/results.jsonl');
    final observedAt = DateTime.utc(2026, 9, 18, 2, 5);

    await candidates.writeAsString(
      '${jsonEncode(<String, Object>{'kind': 'SEGMENT_PAPER_FORWARD', 'observedAt': observedAt.toIso8601String(), 'segmentId': 'ATR_EXPANSION|BUY|TREND', 'side': 'BUY', 'entry': 100.0, 'stop': 99.0, 'target': 102.0, 'rewardRisk': 2.0})}\n',
    );

    final lifecycle = BiQuoteSegmentPaperLifecycle(
      candidateJournal: candidates,
      stateFile: state,
      resultJournal: results,
    );

    await lifecycle.onClosedM5(
      _snapshot(openTime: DateTime.utc(2026, 9, 18, 2, 0), high: 103, low: 98),
    );
    expect(lifecycle.stats.pending, 1);
    expect(lifecycle.stats.ambiguous, 0);

    await lifecycle.onClosedM5(
      _snapshot(
        openTime: DateTime.utc(2026, 9, 18, 2, 5),
        high: 102.2,
        low: 99.5,
      ),
    );
    expect(lifecycle.stats.wins, 1);
    expect(lifecycle.stats.netR, 2.0);
  });

  test('both stop and target on one future M5 is ambiguous', () async {
    final dir = await Directory.systemTemp.createTemp('segment_ambiguous_');
    addTearDown(() => dir.delete(recursive: true));

    final candidates = File('${dir.path}/candidates.jsonl');
    final observedAt = DateTime.utc(2026, 9, 18, 2, 5);
    await candidates.writeAsString(
      '${jsonEncode(<String, Object>{'kind': 'SEGMENT_PAPER_FORWARD', 'observedAt': observedAt.toIso8601String(), 'segmentId': 'LIQ_SWEEP|SELL|RANGE', 'side': 'SELL', 'entry': 100.0, 'stop': 101.0, 'target': 98.0, 'rewardRisk': 2.0})}\n',
    );

    final lifecycle = BiQuoteSegmentPaperLifecycle(
      candidateJournal: candidates,
      stateFile: File('${dir.path}/state.json'),
      resultJournal: File('${dir.path}/results.jsonl'),
    );
    await lifecycle.onClosedM5(
      _snapshot(
        openTime: DateTime.utc(2026, 9, 18, 2, 5),
        high: 101.2,
        low: 97.8,
      ),
    );
    expect(lifecycle.stats.ambiguous, 1);
    expect(lifecycle.stats.netR, 0.0);
  });
}

BiQuoteLiveMarketSnapshot _snapshot({
  required DateTime openTime,
  required double high,
  required double low,
}) {
  final bar = BiQuoteClosedBar(
    symbol: 'XAUUSD',
    timeframe: BiQuoteTimeframe.m5,
    openTime: openTime,
    open: 100,
    high: high,
    low: low,
    close: 100,
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
