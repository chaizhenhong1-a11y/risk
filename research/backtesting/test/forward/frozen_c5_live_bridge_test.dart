import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_episode_validation.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_c5_live_bridge.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_c5_structural_resolver.dart';

StrategyCEpisodeSample row(
  DateTime time, {
  String h4 = 'neutral',
  String h1 = 'bullish',
  String m15 = 'bearish',
  String sweep = 'resistance',
}) => StrategyCEpisodeSample(
  time: time,
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

void main() {
  test('emits only on C5 false to true transition', () {
    FrozenC5StructuralContext context(StrategyCEpisodeSample episode) =>
        FrozenC5StructuralContext(
          time: episode.time,
          entryClose: 4346,
          m15Atr14: 10,
          nearestActiveSupportLowerBound: 4330,
        );

    final bridge = FrozenC5LiveBridge(resolveContext: context);
    final t0 = DateTime.utc(2026, 9, 17, 12);
    final t1 = DateTime.utc(2026, 9, 17, 12, 5);
    final t2 = DateTime.utc(2026, 9, 17, 12, 10);
    final t3 = DateTime.utc(2026, 9, 17, 12, 15);

    expect(bridge.observe(row(t0, h4: 'bullish', h1: 'bullish')), isNull);
    expect(bridge.observe(row(t1)), isNotNull);
    expect(bridge.observe(row(t2)), isNull);
    expect(bridge.observe(row(t3, h4: 'bullish', h1: 'bullish')), isNull);
  });
}
