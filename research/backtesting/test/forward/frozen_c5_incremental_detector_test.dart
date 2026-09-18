import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_episode_validation.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_c5_incremental_detector.dart';

void main() {
  StrategyCEpisodeSample row({required int minute, String h1 = 'bullish'}) {
    return StrategyCEpisodeSample(
      time: DateTime.utc(2026, 9, 17, 8, minute),
      h4: 'neutral',
      h1: h1,
      m15: 'bearish',
      sweep: 'resistance',
      return12: null,
      return24: null,
      return48: null,
      mfe48: null,
      mae48: null,
    );
  }

  test('does not ask for structural risk when there is no new episode', () {
    var calls = 0;
    final detector = FrozenC5IncrementalDetector(
      resolveOpportunity: (episode) {
        calls++;
        return null;
      },
    );

    expect(detector.observe(row(minute: 0, h1: 'neutral')), isNull);
    expect(calls, 0);

    expect(detector.observe(row(minute: 5)), isNull);
    expect(calls, 1);

    // Still inside the same matched episode: no second lookup/signal.
    expect(detector.observe(row(minute: 10)), isNull);
    expect(calls, 1);
  });

  test('missing structural geometry never creates a synthetic C5 trade', () {
    final detector = FrozenC5IncrementalDetector(
      resolveOpportunity: (_) => null,
    );

    expect(detector.observe(row(minute: 0)), isNull);
  });
}
