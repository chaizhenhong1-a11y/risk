import 'paper_signal.dart';

final class PaperTradeResult {
  const PaperTradeResult({
    required this.signalId,
    required this.strategy,
    required this.status,
    required this.resolvedAt,
    required this.grossR,
  });

  final String signalId;
  final String strategy;
  final PaperSignalStatus status;
  final DateTime resolvedAt;
  final double? grossR;
}
