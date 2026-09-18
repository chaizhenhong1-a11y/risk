import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal_activation.dart';

void main() {
  test('A and C5 are active when published into paper-forward', () {
    const activation = PaperSignalActivation();

    expect(activation.initialStatusFor('A'), PaperSignalStatus.triggered);
    expect(activation.initialStatusFor('C5'), PaperSignalStatus.triggered);
  });

  test('unknown strategy does not silently become active', () {
    expect(
      const PaperSignalActivation().initialStatusFor('research-only'),
      PaperSignalStatus.pending,
    );
  });
}
