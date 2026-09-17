import 'dart:convert';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_research_dataset.dart';

void main() {
  test('serializes a stable Strategy C research sample', () {
    final sample = StrategyCResearchSample(
      time: DateTime.utc(2026, 1, 2, 3, 4),
      close: 2500.5,
      h4Structure: 'bullish',
      h1Structure: 'neutral',
      m15Structure: 'bullish',
      regime: 'transition',
      supportSweep: false,
      resistanceSweep: true,
      equalLowSweep: false,
      equalHighSweep: false,
      return12: 2.0,
      return24: 3.0,
      return48: 4.0,
      mfe48: 8.0,
      mae48: 2.5,
    );

    final json = jsonDecode(sample.toJsonLine()) as Map<String, dynamic>;
    expect(json['regime'], 'transition');
    expect(json['resistanceSweep'], isTrue);
    expect(json['return48'], 4.0);
  });
}
