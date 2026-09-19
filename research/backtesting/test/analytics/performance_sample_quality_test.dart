import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/analytics/performance_sample_quality.dart';

void main() {
  const assessor = PerformanceSampleQualityAssessor();

  test('fewer than 30 trades are insufficient', () {
    expect(assessor.assess(5).label, 'INSUFFICIENT SAMPLE');
    expect(assessor.assess(5).isSufficient, isFalse);
  });

  test('30 to 99 trades are early', () {
    expect(assessor.assess(30).label, 'EARLY SAMPLE');
    expect(assessor.assess(99).label, 'EARLY SAMPLE');
  });

  test('100 to 299 trades are developing', () {
    expect(assessor.assess(100).label, 'DEVELOPING SAMPLE');
    expect(assessor.assess(299).label, 'DEVELOPING SAMPLE');
  });

  test('300 or more trades are established', () {
    expect(assessor.assess(300).label, 'ESTABLISHED SAMPLE');
  });
}
