import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_realtime_feed.dart';

void main() {
  test('runtime states keep closed and offline distinct', () {
    expect(
      BiQuoteRuntimeState.marketClosed,
      isNot(BiQuoteRuntimeState.offline),
    );
    expect(BiQuoteRuntimeState.live, isNot(BiQuoteRuntimeState.marketClosed));
  });
}
