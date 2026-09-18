import 'dart:convert';
import 'dart:io';

final class PaperForwardCheckpoint {
  const PaperForwardCheckpoint();

  DateTime? read(File file) {
    if (!file.existsSync()) return null;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported paper checkpoint schema');
    }
    final value = json['lastClosedCandle'] as String?;
    return value == null ? null : DateTime.parse(value);
  }

  void write(File file, DateTime lastClosedCandle) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        // Preserve source wall-clock semantics. The canonical MT5 adapter does
        // not guess broker timezone, so the checkpoint must not silently
        // convert a timezone-unspecified MT5 timestamp through machine local
        // time.
        'lastClosedCandle': lastClosedCandle.toIso8601String(),
      }),
      flush: true,
    );
  }
}
