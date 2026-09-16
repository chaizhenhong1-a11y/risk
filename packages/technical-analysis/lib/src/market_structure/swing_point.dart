enum SwingType { high, low }

final class SwingPoint {
  const SwingPoint({
    required this.type,
    required this.candleIndex,
    required this.price,
  });

  final SwingType type;
  final int candleIndex;
  final double price;
}
