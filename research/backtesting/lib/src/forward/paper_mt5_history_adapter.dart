import 'dart:io';

import '../data/mt5_history_adapter.dart';
import 'paper_candle.dart';

/// Paper-forward bridge to the project's canonical MT5 parser.
///
/// This intentionally reuses [Mt5HistoryAdapter] so forward testing has the
/// same split `<DATE>`/`<TIME>` parsing and M5 open-to-close timestamp semantics as
/// the historical research pipeline.
final class PaperMt5HistoryAdapter {
  const PaperMt5HistoryAdapter({
    this.mt5HistoryAdapter = const Mt5HistoryAdapter(),
  });

  final Mt5HistoryAdapter mt5HistoryAdapter;

  List<PaperCandle> readM5(File file) {
    if (!file.existsSync()) {
      throw ArgumentError.value(file.path, 'file', 'MT5 file does not exist.');
    }

    final series = mt5HistoryAdapter.parse(
      content: file.readAsStringSync(),
      timeframe: MarketTimeframe.m5,
    );

    return series.candles
        .map(
          (candle) => PaperCandle(
            closeTime: candle.closeTime,
            open: candle.open,
            high: candle.high,
            low: candle.low,
            close: candle.close,
          ),
        )
        .toList(growable: false);
  }
}
