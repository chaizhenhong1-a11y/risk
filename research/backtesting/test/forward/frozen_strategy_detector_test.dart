import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_strategy_detector.dart';
import 'package:tradeforge_backtesting/src/forward/paper_candle.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_strategy_opportunity.dart';

void main() {
  final candle = PaperCandle(
    closeTime: DateTime.utc(2026, 9, 17, 8),
    open: 3600,
    high: 3605,
    low: 3595,
    close: 3600,
  );

  test('passes frozen opportunity through unchanged', () {
    final detector = FrozenStrategyDetector(
      strategy: 'A',
      evaluate: (candles) => PaperStrategyOpportunity(
        symbol: 'XAUUSD',
        strategy: 'A',
        side: PaperSignalSide.buy,
        observedAt: candles.last.closeTime,
        entry: 3600,
        stopLoss: 3590,
        takeProfit: 3620,
        reason: 'Frozen A',
      ),
    );

    final result = detector.detect([candle]);
    expect(result, hasLength(1));
    expect(result.single.strategy, 'A');
    expect(result.single.entry, 3600);
  });

  test('null means no opportunity and no synthetic signal is created', () {
    final detector = FrozenStrategyDetector(
      strategy: 'C5',
      evaluate: (_) => null,
    );

    expect(detector.detect([candle]), isEmpty);
  });
}
