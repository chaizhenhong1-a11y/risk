import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('real replay smoke runner declares explicit research configuration', () {
    final file = File('bin/xauusd_replay_smoke.dart');
    expect(file.existsSync(), isTrue);

    final source = file.readAsStringSync();
    expect(source, contains('SignalCandidateHistoricalReplay'));
    expect(source, contains('SetupScoreProfiles.baselineResearchV1'));
    expect(source, contains('AtrStopBufferMultiplier'));
    expect(source, contains('MinimumRiskRewardPolicy'));
    expect(source, contains('matched M15 pullback level midpoint'));
    expect(source, contains('does NOT yet report TP/SL performance'));
  });

  test('smoke runner keeps real-data execution bounded', () {
    final source = File('bin/xauusd_replay_smoke.dart').readAsStringSync();

    expect(source, contains('_defaultSmokeObservations = 250'));
    expect(source, contains('max-observations'));
    expect(source, contains('observations >= maximumObservations'));
  });

  test('smoke runner loads all four frozen MT5 timeframe inputs', () {
    final source = File('bin/xauusd_replay_smoke.dart').readAsStringSync();

    expect(source, contains('XAUUSD_M5_2024_2026.csv'));
    expect(source, contains('XAUUSD_M15_2024_2026.csv'));
    expect(source, contains('XAUUSD_H1_2024_2026.csv'));
    expect(source, contains('XAUUSD_H4_2024_2026.csv'));
  });
}
