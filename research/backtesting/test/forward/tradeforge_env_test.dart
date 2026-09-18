import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/tradeforge_env.dart';

void main() {
  test('loads dotenv values and ignores comments', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge_env_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}.env')
      ..writeAsStringSync('''
# TradeForge
OPENROUTER_API_KEY=test-key
OPENROUTER_MODEL="fixed/free-model"
OPENROUTER_TIMEOUT_MS=12000
''');

    final env = TradeForgeEnv.load(
      path: file.path,
      processEnvironment: const <String, String>{},
    );

    expect(env['OPENROUTER_API_KEY'], 'test-key');
    expect(env['OPENROUTER_MODEL'], 'fixed/free-model');
    expect(env['OPENROUTER_TIMEOUT_MS'], '12000');
  });

  test('process environment overrides dotenv', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge_env_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}.env')
      ..writeAsStringSync('OPENROUTER_MODEL=file-model\n');

    final env = TradeForgeEnv.load(
      path: file.path,
      processEnvironment: const {'OPENROUTER_MODEL': 'process-model'},
    );

    expect(env['OPENROUTER_MODEL'], 'process-model');
  });
}
