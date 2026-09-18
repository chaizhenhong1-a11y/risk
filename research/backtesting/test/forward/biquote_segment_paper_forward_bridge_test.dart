import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/strategy_library/mainstream_strategy_batch.dart';

void main() {
  test('research side remains explicit for segment paper-forward', () {
    expect(
      ResearchSide.values.map((v) => v.name),
      containsAll(<String>['buy', 'sell']),
    );
  });
}
