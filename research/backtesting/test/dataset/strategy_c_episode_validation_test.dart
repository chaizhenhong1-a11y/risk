import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_episode_validation.dart';

void main() {
  const candidate = StrategyCCandidateDefinition(
    id: 'test',
    h4: 'neutral',
    h1: 'bullish',
    m15: 'bearish',
    sweep: 'resistance',
    expectedBullish: true,
  );

  StrategyCEpisodeSample row(DateTime time, double r) => StrategyCEpisodeSample(
    time: time,
    h4: 'neutral',
    h1: 'bullish',
    m15: 'bearish',
    sweep: 'resistance',
    return12: r,
    return24: r,
    return48: r,
    mfe48: 2,
    mae48: 1,
  );

  test('counts contiguous matching observations as one episode', () {
    const validator = StrategyCEpisodeValidator(discoveryFraction: 0.5);
    final rows = [
      row(DateTime.utc(2026, 1, 1, 0, 0), 1),
      row(DateTime.utc(2026, 1, 1, 0, 5), 1),
      StrategyCEpisodeSample(
        time: DateTime.utc(2026, 1, 1, 0, 10),
        h4: 'neutral',
        h1: 'neutral',
        m15: 'neutral',
        sweep: 'none',
        return12: -1,
        return24: -1,
        return48: -1,
        mfe48: 1,
        mae48: 2,
      ),
      row(DateTime.utc(2026, 1, 1, 0, 15), -1),
    ];

    final starts = validator.episodeStarts(rows, candidate);
    expect(starts, hasLength(2));

    final result = validator.validate(rows, candidate);
    expect(result.discovery.episodes, 1);
    expect(result.holdout.episodes, 1);
    expect(result.discovery.success12, 1);
    expect(result.holdout.success12, 0);
  });
}
