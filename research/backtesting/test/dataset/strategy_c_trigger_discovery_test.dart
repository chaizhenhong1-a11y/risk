import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_trigger_discovery.dart';

void main() {
  test('evaluates trigger subset without changing baseline population', () {
    const discovery = C5TriggerDiscovery();
    final episodes = [
      const C5TriggerEpisode(
        bullish: true,
        reclaimPreviousClose: true,
        momentum3: false,
        body: 6,
        range: 10,
        upperWick: 1,
        lowerWick: 3,
        return12: 1,
        return24: 1,
        return48: 1,
        mfe48: 5,
        mae48: 2,
      ),
      const C5TriggerEpisode(
        bullish: false,
        reclaimPreviousClose: false,
        momentum3: false,
        body: 2,
        range: 10,
        upperWick: 4,
        lowerWick: 4,
        return12: -1,
        return24: -1,
        return48: -1,
        mfe48: 2,
        mae48: 5,
      ),
    ];

    final definitions = c5TriggerDefinitions();
    final baseline = discovery.evaluate(episodes, definitions.first);
    final strong = discovery.evaluate(
      episodes,
      definitions.firstWhere((d) => d.id == 'bullish+body>=0.50'),
    );

    expect(baseline.samples, 2);
    expect(strong.samples, 1);
    expect(strong.bullish48, 1);
    expect(strong.avgMfe, 5);
  });
}
