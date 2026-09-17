import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/cache/market_structure_research_cache.dart';

void main() {
  test('round-trips market structure research rows', () {
    final directory = Directory.systemTemp.createTempSync('tf-cache-test-');
    addTearDown(() => directory.deleteSync(recursive: true));

    final file = File('${directory.path}/rows.jsonl');
    const cache = MarketStructureResearchCache();
    final time = DateTime.utc(2026, 1, 2, 3, 4);

    cache.write(file, [
      MarketStructureResearchCacheRow(
        time: time,
        close: 2500.25,
        h4: MarketStructure.neutral,
        h1: MarketStructure.bearish,
        m15: MarketStructure.neutral,
        regime: MarketRegime.transition,
      ),
    ]);

    final rows = cache.read(file);
    expect(rows, hasLength(1));
    expect(rows.single.time, time);
    expect(rows.single.close, 2500.25);
    expect(rows.single.h4, MarketStructure.neutral);
    expect(rows.single.h1, MarketStructure.bearish);
    expect(rows.single.m15, MarketStructure.neutral);
    expect(rows.single.regime, MarketRegime.transition);
  });
}
