import 'dart:convert';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_structural_risk_dataset.dart';

void main() {
  test('serializes structural C5 risk context', () {
    final sample = StrategyCStructuralRiskSample(
      time: DateTime.utc(2026, 1, 1),
      entryClose: 2700,
      m15Atr14: 10,
      supportLowerBound: 2680,
      supportUpperBound: 2682,
      structureDistance: 20,
      atrBuffer: 5,
      bufferedStopPrice: 2675,
      bufferedStopDistance: 25,
    );

    final json = jsonDecode(sample.toJsonLine()) as Map<String, dynamic>;
    expect(json['hasStructuralSupport'], isTrue);
    expect(json['bufferedStopDistance'], 25);
  });

  test('marks a sample without eligible support as unavailable', () {
    final sample = StrategyCStructuralRiskSample(
      time: DateTime.utc(2026, 1, 1),
      entryClose: 2700,
      m15Atr14: 10,
      supportLowerBound: null,
      supportUpperBound: null,
      structureDistance: null,
      atrBuffer: 5,
      bufferedStopPrice: null,
      bufferedStopDistance: null,
    );

    expect(sample.hasStructuralSupport, isFalse);
  });
}
