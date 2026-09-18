import 'dart:io';

import 'paper_candle.dart';

final class PaperCandleCsv {
  const PaperCandleCsv();

  List<PaperCandle> read(File file) {
    if (!file.existsSync()) {
      throw ArgumentError('M5 candle file not found: ${file.path}');
    }

    final lines = file.readAsLinesSync();
    if (lines.isEmpty) return const [];

    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    final header = lines.first
        .split(delimiter)
        .map((value) => _normalize(value))
        .toList();

    final timeIndex = _indexOfAny(header, const [
      'time',
      'datetime',
      'closetime',
      'date',
    ]);
    final openIndex = _indexOfAny(header, const ['open']);
    final highIndex = _indexOfAny(header, const ['high']);
    final lowIndex = _indexOfAny(header, const ['low']);
    final closeIndex = _indexOfAny(header, const ['close']);

    if ([timeIndex, openIndex, highIndex, lowIndex, closeIndex].contains(-1)) {
      throw const FormatException(
        'M5 CSV must contain time/date, open, high, low and close columns.',
      );
    }

    final rows = <PaperCandle>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final values = line.split(delimiter);
      final maxIndex = [
        timeIndex,
        openIndex,
        highIndex,
        lowIndex,
        closeIndex,
      ].reduce((a, b) => a > b ? a : b);
      if (values.length <= maxIndex) continue;

      final time = _parseTime(values[timeIndex].trim());
      rows.add(
        PaperCandle(
          closeTime: time,
          open: double.parse(values[openIndex].trim()),
          high: double.parse(values[highIndex].trim()),
          low: double.parse(values[lowIndex].trim()),
          close: double.parse(values[closeIndex].trim()),
        ),
      );
    }

    rows.sort((a, b) => a.closeTime.compareTo(b.closeTime));
    return rows;
  }

  int _indexOfAny(List<String> header, List<String> names) {
    for (final name in names) {
      final index = header.indexOf(name);
      if (index >= 0) return index;
    }
    return -1;
  }

  String _normalize(String value) => value
      .replaceAll('<', '')
      .replaceAll('>', '')
      .replaceAll('_', '')
      .replaceAll(' ', '')
      .trim()
      .toLowerCase();

  DateTime _parseTime(String value) {
    final direct = DateTime.tryParse(value);
    if (direct != null) return direct.toUtc();

    // MT5 exports commonly use yyyy.MM.dd HH:mm[:ss].
    final normalized = value.replaceFirstMapped(
      RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})'),
      (match) => '${match[1]}-${match[2]}-${match[3]}',
    );
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) {
      throw FormatException('Unsupported candle time: $value');
    }
    return parsed.toUtc();
  }
}
