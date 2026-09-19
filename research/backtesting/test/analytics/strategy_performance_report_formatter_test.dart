import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/analytics/strategy_performance_analytics.dart';
import 'package:tradeforge_backtesting/src/analytics/strategy_performance_report_formatter.dart';

void main() {
  test('prints overall strategy side metrics and sample quality', () {
    final report = analyzeStrategyPerformance([
      const StrategyTradeOutcome(strategy: 'A', side: 'BUY', rMultiple: 2),
      const StrategyTradeOutcome(strategy: 'A', side: 'SELL', rMultiple: -1),
      const StrategyTradeOutcome(strategy: 'B', side: 'SELL', rMultiple: 2),
    ]);

    final text = formatStrategyPerformanceReport(
      report,
      title: 'A/B HISTORICAL PERFORMANCE',
    );

    expect(text, contains('=== A/B HISTORICAL PERFORMANCE ==='));
    expect(text, contains('OVERALL'));
    expect(text, contains('sample=INSUFFICIENT SAMPLE (3/30 minimum)'));
    expect(text, contains('A'));
    expect(text, contains('  BUY'));
    expect(text, contains('  SELL'));
    expect(text, contains('B'));
    expect(text, contains('trades=3 W=2 L=1 BE=0'));
    expect(text, contains('win=66.67% E=1.000R PF=4.000'));
    expect(text, contains('total=3.000R maxDD=1.000R'));
  });
}
