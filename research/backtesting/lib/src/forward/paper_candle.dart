final class PaperCandle {
  const PaperCandle({
    required this.closeTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final DateTime closeTime;
  final double open;
  final double high;
  final double low;
  final double close;
}
