import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/diagnostics/g4_reversal_risk_diagnostics.dart';

void main() {
  test('calculates R expectancy from resolved trades', () {
    const diagnostics = G4ReversalRiskDiagnostics();
    final expectancy = diagnostics.expectancy(const [
      G4ResolvedTrade(riskReward: 2, isWin: true),
      G4ResolvedTrade(riskReward: 2, isWin: false),
      G4ResolvedTrade(riskReward: 2, isWin: false),
    ]);

    expect(expectancy, closeTo(0, 1e-12));
  });
}
