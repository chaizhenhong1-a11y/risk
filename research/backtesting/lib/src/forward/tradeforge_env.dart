import 'dart:io';

class TradeForgeEnv {
  const TradeForgeEnv._();

  static Map<String, String> load({
    String path = '.env',
    Map<String, String>? processEnvironment,
  }) {
    final values = <String, String>{};
    final file = File(path);
    if (file.existsSync()) {
      for (final rawLine in file.readAsLinesSync()) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) {
          continue;
        }
        final separator = line.indexOf('=');
        if (separator <= 0) {
          continue;
        }
        final key = line.substring(0, separator).trim();
        var value = line.substring(separator + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        values[key] = value;
      }
    }

    // Real process environment wins over .env when both exist.
    values.addAll(processEnvironment ?? Platform.environment);
    return Map<String, String>.unmodifiable(values);
  }
}
