import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_episode_validation.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_c5_episode_detector.dart';

void main() {
  StrategyCEpisodeSample row({
    required int minute,
    String h4 = 'neutral',
    String h1 = 'bullish',
    String m15 = 'bearish',
    String sweep = 'resistance',
  }) {
    return StrategyCEpisodeSample(
      time: DateTime.utc(2026, 9, 17, 8, minute),
      h4: h4,
      h1: h1,
      m15: m15,
      sweep: sweep,
      return12: null,
      return24: null,
      return48: null,
      mfe48: null,
      mae48: null,
    );
  }

  test('uses the exact frozen C5 definition', () {
    expect(FrozenC5EpisodeDetector.definition.id, 'C5');
    expect(FrozenC5EpisodeDetector.definition.h4, 'neutral');
    expect(FrozenC5EpisodeDetector.definition.h1, 'bullish');
    expect(FrozenC5EpisodeDetector.definition.m15, 'bearish');
    expect(FrozenC5EpisodeDetector.definition.sweep, 'resistance');
    expect(FrozenC5EpisodeDetector.definition.expectedBullish, isTrue);
  });

  test('emits only false to true episode edges', () {
    final detector = FrozenC5EpisodeDetector();

    expect(detector.observe(row(minute: 0, h1: 'neutral')), isFalse);
    expect(detector.observe(row(minute: 5)), isTrue);
    expect(detector.observe(row(minute: 10)), isFalse);
    expect(detector.observe(row(minute: 15, m15: 'neutral')), isFalse);
    expect(detector.observe(row(minute: 20)), isTrue);
  });

  test('warm-up preserves continuity without emitting history', () {
    final detector = FrozenC5EpisodeDetector();

    detector.warmUp([row(minute: 0, h1: 'neutral'), row(minute: 5)]);

    expect(detector.previousMatched, isTrue);
    expect(detector.observe(row(minute: 10)), isFalse);
  });
}
