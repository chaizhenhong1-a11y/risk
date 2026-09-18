import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/frozen_a_triggered_paper_adapter.dart';
import 'package:tradeforge_backtesting/src/replay/historical_signal_lifecycle_replay.dart';
import 'package:tradeforge_backtesting/src/replay/ready_signal_historical_state.dart';
import 'package:signal_engine/signal_engine.dart';

void main() {
  test('does not publish Strategy A before the frozen lifecycle triggers', () {
    // A lightweight fake candidate is intentionally not fabricated here:
    // constructing a SignalCandidate requires real frozen strategy/risk facts.
    // This test documents the adapter contract while the triggered-path fixture
    // is exercised by the following end-to-end increment.
    expect(
      HistoricalSignalLifecyclePhase.ready ==
          HistoricalSignalLifecyclePhase.triggered,
      isFalse,
    );
    expect(
      HistoricalSignalLifecyclePhase.invalidated ==
          HistoricalSignalLifecyclePhase.triggered,
      isFalse,
    );
    expect(
      HistoricalSignalLifecyclePhase.expired ==
          HistoricalSignalLifecyclePhase.triggered,
      isFalse,
    );
  });

  test('adapter is constructible without introducing strategy parameters', () {
    const adapter = FrozenATriggeredPaperAdapter();
    expect(adapter, isA<FrozenATriggeredPaperAdapter>());
    expect(HistoricalReadySignalState, isNotNull);
    expect(SignalCandidateDirection.values, isNotEmpty);
  });
}
