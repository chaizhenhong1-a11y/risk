import 'package:flutter_test/flutter_test.dart';
import 'package:tradeforge_v2/main.dart';

void main() {
  testWidgets('TradeForge V2 shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TradeForgeApp());

    expect(find.text('TradeForge V2'), findsOneWidget);
  });
}
