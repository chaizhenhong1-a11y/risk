import 'package:flutter_test/flutter_test.dart';
import 'package:tradeforge_mobile/src/domain/tradeforge_live_state.dart';

void main() {
  test('closed market and offline are distinct states', () {
    final closed = TradeForgeLiveState.fromJson(
      <String, dynamic>{'connection': 'marketClosed'},
    );
    final offline = TradeForgeLiveState.fromJson(
      <String, dynamic>{'connection': 'disconnected'},
    );

    expect(closed.connection, LiveConnectionState.marketClosed);
    expect(offline.connection, LiveConnectionState.unavailable);
  });
}
