import 'paper_signal.dart';

/// Paper-forward signals are published at the moment the underlying strategy
/// considers the trade active.
///
/// Strategy A reaches this boundary only after Entry Zone TRIGGERED.
/// C5 enters immediately at its validated episode observation.
final class PaperSignalActivation {
  const PaperSignalActivation();

  PaperSignalStatus initialStatusFor(String strategy) => switch (strategy) {
    'A' || 'C5' => PaperSignalStatus.triggered,
    _ => PaperSignalStatus.pending,
  };
}
