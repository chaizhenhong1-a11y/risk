import 'performance_sample_quality.dart';

String formatPerformanceSampleQuality(int tradeCount) {
  const assessor = PerformanceSampleQualityAssessor();
  final sample = assessor.assess(tradeCount);
  return '${sample.label} '
      '(${sample.tradeCount}/${sample.minimumRequired} minimum)';
}
