import 'package:market_models/market_models.dart';

enum MarketTimeframe {
  m5(Duration(minutes: 5)),
  m15(Duration(minutes: 15)),
  h1(Duration(hours: 1)),
  h4(Duration(hours: 4));

  const MarketTimeframe(this.duration);

  final Duration duration;
}

final class Mt5HistorySeries {
  Mt5HistorySeries({required this.timeframe, required List<Candle> candles})
    : candles = List<Candle>.unmodifiable(candles);

  final MarketTimeframe timeframe;
  final List<Candle> candles;
}

/// Adapter for the tab-separated MT5 history files already used by TradeForge V1.
///
/// Expected columns:
/// `<DATE> <TIME> <OPEN> <HIGH> <LOW> <CLOSE> <TICKVOL> <VOL> <SPREAD>`
///
/// MT5 timestamps are preserved as timezone-unspecified wall-clock values.
/// The adapter deliberately does not guess the broker timezone. Timezone
/// normalization belongs to a later data-policy increment once the source
/// broker/session metadata is known.
final class Mt5HistoryAdapter {
  const Mt5HistoryAdapter();

  Mt5HistorySeries parse({
    required String content,
    required MarketTimeframe timeframe,
  }) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      throw const FormatException('MT5 history file is empty.');
    }

    final header = _splitRow(lines.first);
    _validateHeader(header);

    final candles = <Candle>[];

    for (var lineIndex = 1; lineIndex < lines.length; lineIndex++) {
      final columns = _splitRow(lines[lineIndex]);
      if (columns.length != 9) {
        throw FormatException(
          'Invalid MT5 row at line ${lineIndex + 1}: '
          'expected 9 columns, got ${columns.length}.',
        );
      }

      final openTime = _parseDateTime(
        columns[0],
        columns[1],
        lineNumber: lineIndex + 1,
      );

      candles.add(
        Candle(
          openTime: openTime,
          closeTime: openTime.add(timeframe.duration),
          open: _parseDouble(columns[2], '<OPEN>', lineIndex + 1),
          high: _parseDouble(columns[3], '<HIGH>', lineIndex + 1),
          low: _parseDouble(columns[4], '<LOW>', lineIndex + 1),
          close: _parseDouble(columns[5], '<CLOSE>', lineIndex + 1),
          // V1 MT5 exports have real activity in <TICKVOL> while <VOL> is 0.
          // Preserve that useful historical activity measure in Candle.volume.
          volume: _parseDouble(columns[6], '<TICKVOL>', lineIndex + 1),
        ),
      );
    }

    _validateChronology(candles);

    return Mt5HistorySeries(timeframe: timeframe, candles: candles);
  }

  List<String> _splitRow(String row) =>
      row.split('\t').map((value) => value.trim()).toList(growable: false);

  void _validateHeader(List<String> header) {
    const expected = [
      '<DATE>',
      '<TIME>',
      '<OPEN>',
      '<HIGH>',
      '<LOW>',
      '<CLOSE>',
      '<TICKVOL>',
      '<VOL>',
      '<SPREAD>',
    ];

    if (header.length != expected.length) {
      throw const FormatException('Unsupported MT5 history header.');
    }

    for (var index = 0; index < expected.length; index++) {
      if (header[index] != expected[index]) {
        throw FormatException(
          'Unsupported MT5 history header at column ${index + 1}: '
          'expected ${expected[index]}, got ${header[index]}.',
        );
      }
    }
  }

  DateTime _parseDateTime(String date, String time, {required int lineNumber}) {
    final dateParts = date.split('.');
    final timeParts = time.split(':');

    if (dateParts.length != 3 || timeParts.length != 3) {
      throw FormatException(
        'Invalid MT5 date/time at line $lineNumber: $date $time.',
      );
    }

    try {
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = int.parse(timeParts[2]);

      final parsed = DateTime(year, month, day, hour, minute, second);

      if (parsed.year != year ||
          parsed.month != month ||
          parsed.day != day ||
          parsed.hour != hour ||
          parsed.minute != minute ||
          parsed.second != second) {
        throw const FormatException();
      }

      return parsed;
    } on FormatException {
      throw FormatException(
        'Invalid MT5 date/time at line $lineNumber: $date $time.',
      );
    }
  }

  double _parseDouble(String raw, String column, int lineNumber) {
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite) {
      throw FormatException('Invalid $column value at line $lineNumber: $raw.');
    }
    return value;
  }

  void _validateChronology(List<Candle> candles) {
    for (var index = 1; index < candles.length; index++) {
      if (!candles[index].openTime.isAfter(candles[index - 1].openTime)) {
        throw FormatException(
          'MT5 candles must be strictly chronological. '
          'Invalid order at data rows $index and ${index + 1}.',
        );
      }
    }
  }
}
