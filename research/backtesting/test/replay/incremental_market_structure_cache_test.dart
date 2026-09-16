import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  test('incremental cache matches frozen full analyzer for every prefix', () {
    const analyzer = MarketStructureAnalyzer();
    final cache = IncrementalMarketStructureCache();
    final candles = List.generate(80, _candle);

    for (var length = 1; length <= candles.length; length++) {
      final prefix = candles.sublist(0, length);
      final expected = analyzer.analyze(prefix, equalityTolerance: 0.1);
      final actual = cache.update(prefix, equalityTolerance: 0.1);

      expect(actual.structure, expected.structure, reason: 'prefix=$length');
      expect(
        actual.highRelationship,
        expected.highRelationship,
        reason: 'prefix=$length high relationship',
      );
      expect(
        actual.lowRelationship,
        expected.lowRelationship,
        reason: 'prefix=$length low relationship',
      );
      expect(
        actual.swings.map(_signature).toList(),
        expected.swings.map(_signature).toList(),
        reason: 'prefix=$length swings',
      );
    }
  });

  test('rebuilds safely when supplied history shrinks', () {
    const analyzer = MarketStructureAnalyzer();
    final cache = IncrementalMarketStructureCache();
    final candles = List.generate(40, _candle);

    cache.update(candles, equalityTolerance: 0.1);
    final shortened = candles.sublist(0, 17);
    final expected = analyzer.analyze(shortened, equalityTolerance: 0.1);
    final actual = cache.update(shortened, equalityTolerance: 0.1);

    expect(actual.structure, expected.structure);
    expect(actual.highRelationship, expected.highRelationship);
    expect(actual.lowRelationship, expected.lowRelationship);
    expect(
      actual.swings.map(_signature).toList(),
      expected.swings.map(_signature).toList(),
    );
  });
}

String _signature(SwingPoint swing) =>
    '${swing.type.name}:${swing.candleIndex}:${swing.price}';

Candle _candle(int index) {
  final center = 2000 + (index % 13) * 1.7 - (index % 7) * 1.1;
  final open = center - 0.2;
  final close = center + 0.2;
  final start = DateTime.utc(2026, 1, 1).add(Duration(minutes: 15 * index));
  return Candle(
    openTime: start,
    closeTime: start.add(const Duration(minutes: 15)),
    open: open,
    high: center + 1.0,
    low: center - 1.0,
    close: close,
    volume: 100,
  );
}
