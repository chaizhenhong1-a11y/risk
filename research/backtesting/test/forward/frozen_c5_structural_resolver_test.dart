import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_episode_validation.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_c5_structural_resolver.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';

void main() {
  test('uses frozen support minus ATR14 x 0.50 stop and 2R target', () {
    final time = DateTime.utc(2026, 9, 17, 12, 5);
    final episode = StrategyCEpisodeSample(
      time: time,
      h4: 'neutral',
      h1: 'bullish',
      m15: 'bearish',
      sweep: 'resistance',
      return12: null,
      return24: null,
      return48: null,
      mfe48: null,
      mae48: null,
    );

    final opportunity = const FrozenC5StructuralResolver().resolve(
      episode: episode,
      context: FrozenC5StructuralContext(
        time: time,
        entryClose: 4346,
        m15Atr14: 10,
        nearestActiveSupportLowerBound: 4330,
      ),
    );

    expect(opportunity.strategy, 'C5');
    expect(opportunity.side, PaperSignalSide.buy);
    expect(opportunity.entry, 4346);
    expect(opportunity.stopLoss, 4325);
    expect(opportunity.takeProfit, 4388);
    expect(opportunity.observedAt, time);
  });

  test('rejects mismatched episode/context timestamps', () {
    final episode = StrategyCEpisodeSample(
      time: DateTime.utc(2026, 9, 17, 12, 5),
      h4: 'neutral',
      h1: 'bullish',
      m15: 'bearish',
      sweep: 'resistance',
      return12: null,
      return24: null,
      return48: null,
      mfe48: null,
      mae48: null,
    );

    expect(
      () => const FrozenC5StructuralResolver().resolve(
        episode: episode,
        context: FrozenC5StructuralContext(
          time: DateTime.utc(2026, 9, 17, 12, 10),
          entryClose: 4346,
          m15Atr14: 10,
          nearestActiveSupportLowerBound: 4330,
        ),
      ),
      throwsStateError,
    );
  });
}
