import 'dart:io';

import 'package:test/test.dart';

void main() {
  final file = File('bin/xauusd_full_lifecycle_backtest.dart');

  test('real lifecycle runner wires frozen lifecycle, records, and report', () {
    expect(file.existsSync(), isTrue);
    final source = file.readAsStringSync();

    expect(source, contains('HistoricalSignalLifecycleReplay'));
    expect(source, contains('HistoricalSignalRecordBuilder'));
    expect(source, contains('BacktestRunReportBuilder'));
    expect(source, contains('Triggered resolved trades'));
    expect(source, contains('Expectancy R'));
    expect(source, contains('Profit factor'));
  });

  test('first real lifecycle research assumptions are explicit', () {
    final source = file.readAsStringSync();

    expect(source, contains('_maximumWaitingCandles = 12'));
    expect(
      source,
      contains("stdout.writeln('  minimumRR=\$_minimumRiskReward');"),
    );
    expect(source, contains('matched M15 pullback level midpoint'));
    expect(source, contains('one signal plan at a time'));
    expect(source, contains('terminal candle is not reused'));
    expect(source, contains('explicit, uncalibrated'));
  });

  test('runner preserves the four verified real MT5 inputs', () {
    final source = file.readAsStringSync();

    expect(source, contains('XAUUSD_M5_2024_2026.csv'));
    expect(source, contains('XAUUSD_M15_2024_2026.csv'));
    expect(source, contains('XAUUSD_H1_2024_2026.csv'));
    expect(source, contains('XAUUSD_H4_2024_2026.csv'));
  });

  test(
    'real lifecycle run remains bounded before full-history optimization',
    () {
      final source = file.readAsStringSync();

      expect(source, contains('_defaultMaximumObservations = 100049'));
      expect(source, contains('max-observations'));
      expect(source, contains('observations >= maximumObservations'));
    },
  );

  test('larger-window replay exposes progress and timing diagnostics', () {
    final source = file.readAsStringSync();

    expect(source, contains('_progressInterval = 1000'));
    expect(
      source,
      contains('Progress: \$observations/\$maximumObservations M5'),
    );
    expect(source, contains('Elapsed replay time:'));
    expect(source, contains('Average replay rate:'));
  });

  test('runner exposes opportunity-frequency diagnostics', () {
    final source = File(
      'bin/xauusd_full_lifecycle_backtest.dart',
    ).readAsStringSync();

    expect(source, contains('Gate funnel diagnostics:'));
    expect(source, contains('blocked — H4/H1 no-trade bias:'));
    expect(source, contains('blocked — directional pullback absent:'));
    expect(source, contains('blocked — insufficient ATR history:'));
    expect(source, contains('reached risk analysis:'));
    expect(source, contains('risk eligible:'));
    expect(source, contains('risk blocked — '));
    expect(source, contains('reason.name'));
    expect(source, contains('Opportunity frequency diagnostics:'));
    expect(source, contains('observed trading dates:'));
    expect(source, contains('all qualified candidate observations:'));
    expect(source, contains('unique qualified opportunity episodes:'));
    expect(source, contains('qualified plans per observed trading date:'));
    expect(
      source,
      contains(
        'all qualified candidate observations per observed trading date:',
      ),
    );
    expect(
      source,
      contains('unique qualified opportunities per observed trading date:'),
    );
    expect(source, contains('active-plan suppression share:'));
  });

  test('runner exposes market-regime historical diagnostics', () {
    final source = file.readAsStringSync();

    expect(source, contains('MarketRegimeClassifier'));
    expect(source, contains('Market regime historical diagnostics:'));
    expect(source, contains('range requires explicit range evidence'));
    expect(source, contains('avgEpisodeM5='));
    expect(source, contains('maxEpisodeM5='));
    expect(source, contains('for (final regime in MarketRegime.values)'));
  });
}
