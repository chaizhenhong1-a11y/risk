import 'dart:convert';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_forward_path_dataset.dart';

void main() {
  test('serializes ordered forward M5 path', () {
    final episode = StrategyCForwardPathEpisode(
      time: DateTime.utc(2026, 1, 1),
      entryOpen: 100,
      entryHigh: 102,
      entryLow: 99,
      entryClose: 101,
      forwardBars: const [
        StrategyCForwardBar(
          offset: 1,
          open: 101,
          high: 103,
          low: 100,
          close: 102,
        ),
        StrategyCForwardBar(
          offset: 2,
          open: 102,
          high: 104,
          low: 101,
          close: 103,
        ),
      ],
    );

    final json = jsonDecode(episode.toJsonLine()) as Map<String, dynamic>;
    final bars = json['forwardBars'] as List<dynamic>;
    expect(bars, hasLength(2));
    expect((bars[1] as Map<String, dynamic>)['offset'], 2);
  });
}
