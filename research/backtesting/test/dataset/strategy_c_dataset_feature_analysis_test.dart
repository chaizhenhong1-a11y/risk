import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_dataset_feature_analysis.dart';

void main() {
  test('groups cached Strategy C rows and measures forward direction', () {
    const analyzer = StrategyCDatasetFeatureAnalyzer();
    final groups = analyzer.analyze([
      const StrategyCDatasetRow(
        h4: 'bullish',
        h1: 'neutral',
        m15: 'bullish',
        sweep: 'none',
        return12: 1,
        return24: 2,
        return48: -1,
        mfe48: 5,
        mae48: 2,
      ),
      const StrategyCDatasetRow(
        h4: 'bullish',
        h1: 'neutral',
        m15: 'bullish',
        sweep: 'none',
        return12: -1,
        return24: 3,
        return48: 1,
        mfe48: 4,
        mae48: 3,
      ),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.samples, 2);
    expect(groups.single.bullish12, 1);
    expect(groups.single.bullish24, 2);
    expect(groups.single.avgMfe, 4.5);
    expect(groups.single.avgMae, 2.5);
  });
}
