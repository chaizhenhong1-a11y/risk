import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/dataset/strategy_c_structural_lifecycle_validation.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_c5_paper_adapter.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';

void main() {
  test('converts frozen C5 structural geometry to BUY at exactly 2R', () {
    final risk = C5StructuralRisk(
      time: DateTime.utc(2026, 9, 17, 8),
      entryClose: 3600,
      m15Atr14: 10,
      supportLowerBound: 3590,
      bufferedStopPrice: 3585,
      bufferedStopDistance: 15,
    );

    final opportunity = const FrozenC5PaperAdapter().convert(risk);

    expect(opportunity.strategy, 'C5');
    expect(opportunity.side, PaperSignalSide.buy);
    expect(opportunity.entry, 3600);
    expect(opportunity.stopLoss, 3585);
    expect(opportunity.takeProfit, 3630);
  });

  test('rejects invalid C5 geometry rather than manufacturing a signal', () {
    final risk = C5StructuralRisk(
      time: DateTime.utc(2026, 9, 17, 8),
      entryClose: 3600,
      m15Atr14: 10,
      supportLowerBound: 3601,
      bufferedStopPrice: 3605,
      bufferedStopDistance: -5,
    );

    expect(
      () => const FrozenC5PaperAdapter().convert(risk),
      throwsArgumentError,
    );
  });
}
