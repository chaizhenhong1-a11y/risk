import '../forward/paper_signal.dart';
import '../forward/paper_trade_result.dart';
import 'paper_forward_performance_adapter.dart';
import 'strategy_performance_analytics.dart';

/// Normalizes resolved production-strategy forward results into the shared
/// performance analytics model.
///
/// The adapter deliberately joins results back to their original PaperSignal so
/// side and observation time come from the recorded formal signal rather than
/// being reconstructed from an ID. Candidate-only/expired opportunities are not
/// counted because only results with a finite realized R become trades.
final class UnifiedForwardPerformanceAdapter {
  const UnifiedForwardPerformanceAdapter({
    this.productionStrategies = const {'A', 'B', 'C5'},
  });

  final Set<String> productionStrategies;

  StrategyPerformanceBreakdown analyze({
    required Iterable<PaperSignal> signals,
    required Iterable<PaperTradeResult> results,
  }) {
    final signalsById = <String, PaperSignal>{
      for (final signal in signals) signal.id: signal,
    };
    final normalized = <PaperForwardResult>[];

    for (final result in results) {
      final realizedR = result.grossR;
      if (realizedR == null || !realizedR.isFinite) continue;

      final signal = signalsById[result.signalId];
      if (signal == null) {
        throw StateError(
          'Resolved forward result ${result.signalId} has no matching signal.',
        );
      }
      if (signal.strategy != result.strategy) {
        throw StateError(
          'Strategy mismatch for ${result.signalId}: '
          'signal=${signal.strategy}, result=${result.strategy}.',
        );
      }
      if (!productionStrategies.contains(result.strategy)) continue;

      normalized.add(
        PaperForwardResult(
          strategy: result.strategy,
          side: switch (signal.side) {
            PaperSignalSide.buy => 'BUY',
            PaperSignalSide.sell => 'SELL',
          },
          observedAt: signal.observedAt,
          realizedR: realizedR,
        ),
      );
    }

    return const PaperForwardPerformanceAdapter().analyze(normalized);
  }
}
