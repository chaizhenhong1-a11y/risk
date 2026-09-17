import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_entry_timing_analysis.dart';

void main() {
  test('measures first positive close and pre-positive adverse excursion', () {
    final path = C5ForwardPath(
      time: DateTime.utc(2026),
      entryClose: 100,
      bars: const [
        C5PathBar(offset: 1, open: 100, high: 101, low: 98, close: 99),
        C5PathBar(offset: 2, open: 99, high: 102, low: 97, close: 101),
        C5PathBar(offset: 3, open: 101, high: 104, low: 100, close: 103),
      ],
    );

    const analysis = C5EntryTimingAnalysis();
    final stats = analysis.analyze([path], 3);

    expect(stats.samples, 1);
    expect(stats.bullishCloseRate, 1);
    expect(stats.firstPositiveCloseMedianOffset, 2);
    expect(stats.maeBeforeFirstPositiveCloseMedian, 3);
    expect(stats.averageMfe, 4);
    expect(stats.averageMae, 3);
  });
}
