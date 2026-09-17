import 'dart:convert';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_trigger_research_dataset.dart';

void main() {
  test('derives deterministic M5 trigger features', () {
    final sample = StrategyCTriggerResearchSample(
      time: DateTime.utc(2026, 1, 1),
      open: 100,
      high: 104,
      low: 99,
      close: 103,
      previousClose: 102,
      previous2Close: 101,
      previous3Close: 100,
      h4Structure: 'neutral',
      h1Structure: 'bullish',
      m15Structure: 'bearish',
      resistanceSweep: true,
      return12: 2,
      return24: 3,
      return48: 4,
      mfe48: 6,
      mae48: 2,
    );

    expect(sample.bullish, isTrue);
    expect(sample.reclaimPreviousClose, isTrue);
    expect(sample.momentum3, isTrue);
    expect(sample.body, 3);
    expect(sample.upperWick, 1);
    expect(sample.lowerWick, 1);

    final json = jsonDecode(sample.toJsonLine()) as Map<String, dynamic>;
    expect(json['momentum3'], isTrue);
    expect(json['body'], 3);
  });
}
