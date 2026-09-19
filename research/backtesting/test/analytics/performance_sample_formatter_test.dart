import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/analytics/performance_sample_formatter.dart';

void main() {
  test('formats insufficient sample with progress toward minimum', () {
    expect(
      formatPerformanceSampleQuality(5),
      'INSUFFICIENT SAMPLE (5/30 minimum)',
    );
  });

  test('formats early sample after minimum is reached', () {
    expect(formatPerformanceSampleQuality(30), 'EARLY SAMPLE (30/30 minimum)');
  });

  test('formats developing and established samples', () {
    expect(
      formatPerformanceSampleQuality(100),
      'DEVELOPING SAMPLE (100/30 minimum)',
    );
    expect(
      formatPerformanceSampleQuality(300),
      'ESTABLISHED SAMPLE (300/30 minimum)',
    );
  });
}
