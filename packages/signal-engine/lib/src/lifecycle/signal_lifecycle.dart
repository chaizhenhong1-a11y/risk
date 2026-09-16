/// Baseline lifecycle states for TradeForge V2 signal discovery.
///
/// Increment 048 intentionally implements only the pre-trigger path:
///
/// scanning -> watching -> setupForming -> ready -> triggered
///
/// Increment 049 adds only the READY -> TRIGGERED transition. ACTIVE and
/// outcome/terminal states remain intentionally outside this increment.
enum SignalLifecycleState { scanning, watching, setupForming, ready, triggered }

enum SignalLifecycleTransitionFailure {
  sameState,
  backwardTransition,
  skippedState,
}

/// Result of one deterministic lifecycle transition attempt.
final class SignalLifecycleTransition {
  const SignalLifecycleTransition._({
    required this.from,
    required this.to,
    required this.isAllowed,
    this.failure,
  });

  const SignalLifecycleTransition.allowed({
    required SignalLifecycleState from,
    required SignalLifecycleState to,
  }) : this._(from: from, to: to, isAllowed: true);

  const SignalLifecycleTransition.rejected({
    required SignalLifecycleState from,
    required SignalLifecycleState to,
    required SignalLifecycleTransitionFailure failure,
  }) : this._(from: from, to: to, isAllowed: false, failure: failure);

  final SignalLifecycleState from;
  final SignalLifecycleState to;
  final bool isAllowed;
  final SignalLifecycleTransitionFailure? failure;
}

/// Validates the baseline lifecycle through TRIGGERED.
///
/// Only the next adjacent forward state is allowed. This prevents a signal from
/// silently skipping required lifecycle stages or moving backward without a
/// future explicit reset/invalidation rule.
final class SignalLifecycle {
  const SignalLifecycle();

  SignalLifecycleTransition transition({
    required SignalLifecycleState from,
    required SignalLifecycleState to,
  }) {
    final fromIndex = from.index;
    final toIndex = to.index;

    if (toIndex == fromIndex) {
      return SignalLifecycleTransition.rejected(
        from: from,
        to: to,
        failure: SignalLifecycleTransitionFailure.sameState,
      );
    }

    if (toIndex < fromIndex) {
      return SignalLifecycleTransition.rejected(
        from: from,
        to: to,
        failure: SignalLifecycleTransitionFailure.backwardTransition,
      );
    }

    if (toIndex != fromIndex + 1) {
      return SignalLifecycleTransition.rejected(
        from: from,
        to: to,
        failure: SignalLifecycleTransitionFailure.skippedState,
      );
    }

    return SignalLifecycleTransition.allowed(from: from, to: to);
  }
}
