import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_episode_validation.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_robustness_validation.dart';

void main() {
  test('splits independent episodes into chronological windows', () {
    const candidate = StrategyCCandidateDefinition(
      id: 'C5',
      h4: 'neutral',
      h1: 'bullish',
      m15: 'bearish',
      sweep: 'resistance',
      expectedBullish: true,
    );

    final rows = <StrategyCEpisodeSample>[];
    for (var i = 0; i < 10; i++) {
      rows.add(
        StrategyCEpisodeSample(
          time: DateTime.utc(2026, 1, 1).add(Duration(hours: i * 2)),
          h4: 'neutral',
          h1: 'bullish',
          m15: 'bearish',
          sweep: 'resistance',
          return12: 1,
          return24: 1,
          return48: 1,
          mfe48: 2,
          mae48: 1,
        ),
      );
      rows.add(
        StrategyCEpisodeSample(
          time: DateTime.utc(2026, 1, 1).add(Duration(hours: i * 2 + 1)),
          h4: 'neutral',
          h1: 'neutral',
          m15: 'neutral',
          sweep: 'none',
          return12: 0,
          return24: 0,
          return48: 0,
          mfe48: 0,
          mae48: 0,
        ),
      );
    }

    const validator = StrategyCRobustnessValidator(windowCount: 5);
    final result = validator.validate(rows, candidate);

    expect(result.windows, hasLength(5));
    expect(result.windows.every((w) => w.stats.episodes == 2), isTrue);
    expect(result.windows.first.stats.success48, 2);
  });
}
