import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'real-history inspection runner exists and names all required files',
    () {
      final file = File('bin/xauusd_csv_inspect.dart');
      expect(file.existsSync(), isTrue);

      final source = file.readAsStringSync();
      expect(source, contains('XAUUSD_M5_2024_2026.csv'));
      expect(source, contains('XAUUSD_M15_2024_2026.csv'));
      expect(source, contains('XAUUSD_H1_2024_2026.csv'));
      expect(source, contains('XAUUSD_H4_2024_2026.csv'));
      expect(source, contains('broker wall-clock'));
      expect(source, contains('No strategy metrics were produced'));
    },
  );
}
