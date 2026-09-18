import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_candle.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_coordinator.dart';
import 'package:tradeforge_backtesting/src/forward/paper_opportunity_detector.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_strategy_opportunity.dart';

final class _Detector implements PaperOpportunityDetector {
  const _Detector(this.strategy);

  @override
  final String strategy;

  @override
  List<PaperStrategyOpportunity> detect(List<PaperCandle> closedCandles) {
    final candle = closedCandles.last;
    return [
      PaperStrategyOpportunity(
        symbol: 'XAUUSD',
        strategy: strategy,
        side: PaperSignalSide.buy,
        observedAt: candle.closeTime,
        entry: candle.close,
        stopLoss: candle.close - 10,
        takeProfit: candle.close + 20,
        reason: 'Frozen $strategy test opportunity',
      ),
    ];
  }
}

void main() {
  test('runs A and C5 independently then updates one paper session', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-coordinator-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final signals = File('${dir.path}${Platform.pathSeparator}signals.jsonl');
    final results = File('${dir.path}${Platform.pathSeparator}results.jsonl');

    final report = const PaperForwardCoordinator().run(
      closedCandles: [
        PaperCandle(
          closeTime: DateTime.utc(2026, 9, 17, 8),
          open: 3600,
          high: 3605,
          low: 3595,
          close: 3600,
        ),
      ],
      detectors: const [_Detector('A'), _Detector('C5')],
      signalsFile: signals,
      resultsFile: results,
    );

    expect(report.detected, 2);
    expect(report.recorded, 2);
    expect(report.duplicates, 0);
    expect(report.session.signals, 2);
  });

  test('rerun deduplicates the same strategy opportunities', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-dedupe-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final signals = File('${dir.path}${Platform.pathSeparator}signals.jsonl');
    final results = File('${dir.path}${Platform.pathSeparator}results.jsonl');
    const coordinator = PaperForwardCoordinator();
    final candles = [
      PaperCandle(
        closeTime: DateTime.utc(2026, 9, 17, 8),
        open: 3600,
        high: 3605,
        low: 3595,
        close: 3600,
      ),
    ];

    coordinator.run(
      closedCandles: candles,
      detectors: const [_Detector('A'), _Detector('C5')],
      signalsFile: signals,
      resultsFile: results,
    );
    final second = coordinator.run(
      closedCandles: candles,
      detectors: const [_Detector('A'), _Detector('C5')],
      signalsFile: signals,
      resultsFile: results,
    );

    expect(second.recorded, 0);
    expect(second.duplicates, 2);
  });
}
