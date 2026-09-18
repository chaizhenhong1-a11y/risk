import 'package:flutter_test/flutter_test.dart';
import 'package:tradeforge_mobile/src/app/tradeforge_app.dart';

void main() {
  testWidgets('renders minimal TradeForge navigation', (tester) async {
    await tester.pumpWidget(const TradeForgeApp());

    expect(find.text('TradeForge'), findsOneWidget);
    expect(find.text('市场'), findsOneWidget);
    expect(find.text('信号'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('正在扫描市场'), findsOneWidget);
  });
}
