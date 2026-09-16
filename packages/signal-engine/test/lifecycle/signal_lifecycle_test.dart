import 'package:signal_engine/signal_engine.dart';
import 'package:test/test.dart';

void main() {
  const lifecycle = SignalLifecycle();

  group('SignalLifecycle pre-trigger foundation', () {
    test('SCANNING can advance to WATCHING', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.scanning,
        to: SignalLifecycleState.watching,
      );

      expect(result.isAllowed, isTrue);
      expect(result.failure, isNull);
    });

    test('WATCHING can advance to SETUP_FORMING', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.watching,
        to: SignalLifecycleState.setupForming,
      );

      expect(result.isAllowed, isTrue);
    });

    test('SETUP_FORMING can advance to READY', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.setupForming,
        to: SignalLifecycleState.ready,
      );

      expect(result.isAllowed, isTrue);
    });

    test('cannot skip directly from SCANNING to READY', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.scanning,
        to: SignalLifecycleState.ready,
      );

      expect(result.isAllowed, isFalse);
      expect(result.failure, SignalLifecycleTransitionFailure.skippedState);
    });

    test('cannot move backward', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.ready,
        to: SignalLifecycleState.setupForming,
      );

      expect(result.isAllowed, isFalse);
      expect(
        result.failure,
        SignalLifecycleTransitionFailure.backwardTransition,
      );
    });

    test('same-state transition is explicit rejection', () {
      final result = lifecycle.transition(
        from: SignalLifecycleState.watching,
        to: SignalLifecycleState.watching,
      );

      expect(result.isAllowed, isFalse);
      expect(result.failure, SignalLifecycleTransitionFailure.sameState);
    });
  });
}
