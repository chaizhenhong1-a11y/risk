import 'performance_sample_formatter.dart';
import 'strategy_performance_analytics.dart';

String formatStrategyPerformanceReport(
  StrategyPerformanceBreakdown report, {
  required String title,
}) {
  final buffer = StringBuffer()
    ..writeln('=== $title ===')
    ..writeln();

  _writeMetrics(buffer, 'OVERALL', report.overall);

  for (final entry in report.byStrategy.entries) {
    buffer.writeln();
    _writeMetrics(buffer, entry.key, entry.value);

    final sides = report.byStrategyAndSide[entry.key] ?? const {};
    for (final side in sides.entries) {
      buffer.writeln();
      _writeMetrics(buffer, '  ${side.key}', side.value);
    }
  }

  return buffer.toString().trimRight();
}

void _writeMetrics(
  StringBuffer buffer,
  String label,
  StrategyPerformanceMetrics metrics,
) {
  buffer
    ..writeln(label)
    ..writeln('  sample=${formatPerformanceSampleQuality(metrics.tradeCount)}')
    ..writeln(
      '  trades=${metrics.tradeCount} W=${metrics.winCount} '
      'L=${metrics.lossCount} BE=${metrics.breakEvenCount}',
    )
    ..writeln(
      '  win=${_percent(metrics.winRate)} '
      'E=${_r(metrics.expectancyR)} '
      'PF=${_factor(metrics.profitFactor)}',
    )
    ..writeln(
      '  total=${metrics.totalR.toStringAsFixed(3)}R '
      'maxDD=${metrics.maxDrawdownR.toStringAsFixed(3)}R',
    );
}

String _percent(double? value) =>
    value == null ? 'n/a' : '${(value * 100).toStringAsFixed(2)}%';

String _r(double? value) =>
    value == null ? 'n/a' : '${value.toStringAsFixed(3)}R';

String _factor(double? value) {
  if (value == null) return 'n/a';
  if (value.isInfinite) return 'inf';
  return value.toStringAsFixed(3);
}
