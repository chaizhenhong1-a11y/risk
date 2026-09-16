import 'package:signal_engine/signal_engine.dart';
import 'package:test/test.dart';

void main() {
  const lifecycle = SignalLifecycle();

  group('READY to TRIGGERED lifecycle transition', () {
    test('READY can advance to TRIGGERED', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.ready,
        to: SignalLifecycleState.triggered,
      );

      expect(result.isAllowed, isTrue);
      expect(result.failure, isNull);
    });

    test('SETUP_FORMING cannot skip READY and jump to TRIGGERED', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.setupForming,
        to: SignalLifecycleState.triggered,
      );

      expect(result.isAllowed, isFalse);
      expect(result.failure, SignalLifecycleTransitionFailure.skippedState);
    });

    test('TRIGGERED cannot move backward to READY', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.triggered,
        to: SignalLifecycleState.ready,
      );

      expect(result.isAllowed, isFalse);
      expect(
        result.failure,
        SignalLifecycleTransitionFailure.backwardTransition,
      );
    });

    test('TRIGGERED to TRIGGERED is rejected explicitly', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.triggered,
        to: SignalLifecycleState.triggered,
      );

      expect(result.isAllowed, isFalse);
      expect(result.failure, SignalLifecycleTransitionFailure.sameState);
    });
  });
}
