import '../forward/biquote_live_market_snapshot.dart';
import 'strategy_registry.dart';

enum RoutedMarketRegime {
  warmingUp,
  trend,
  pullback,
  momentum,
  breakout,
  range,
  transition,
  volatilityExpansion,
}

final class MarketRoute {
  const MarketRoute({
    required this.regime,
    required this.reason,
    required this.activeFamilies,
  });
  final RoutedMarketRegime regime;
  final String reason;
  final Set<StrategyMarketFamily> activeFamilies;
}

/// Lightweight routing layer only. It decides which research families are
/// relevant; it does not approve trades and cannot promote research strategies.
final class MarketRegimeRouter {
  const MarketRegimeRouter();

  MarketRoute route(BiQuoteLiveMarketSnapshot snapshot) {
    if (snapshot.m5.length < 20 ||
        snapshot.m15.length < 20 ||
        snapshot.h1.length < 12) {
      return const MarketRoute(
        regime: RoutedMarketRegime.warmingUp,
        reason: '等待足够 CLOSED bars 建立市场状态。',
        activeFamilies: <StrategyMarketFamily>{},
      );
    }
    final m5 = snapshot.m5;
    final h1 = snapshot.h1;
    final last = m5.last;
    final recent = m5.sublist(m5.length - 20);
    final range =
        recent.map((b) => b.high).reduce((a, b) => a > b ? a : b) -
        recent.map((b) => b.low).reduce((a, b) => a < b ? a : b);
    final avgRange =
        recent.fold<double>(0, (sum, b) => sum + (b.high - b.low)) /
        recent.length;
    final body = (last.close - last.open).abs();
    final h1Move = h1.last.close - h1[h1.length - 12].close;
    final directional = h1Move.abs() > avgRange * 3;
    final expanding = avgRange > 0 && body > avgRange * 1.6;
    final nearEdge =
        range > 0 &&
        ((last.close -
                        recent
                            .map((b) => b.low)
                            .reduce((a, b) => a < b ? a : b)) /
                    range >
                .9 ||
            (recent.map((b) => b.high).reduce((a, b) => a > b ? a : b) -
                        last.close) /
                    range >
                .9);

    if (directional && expanding) {
      return const MarketRoute(
        regime: RoutedMarketRegime.momentum,
        reason: 'H1 directional move + M5 range expansion.',
        activeFamilies: {
          StrategyMarketFamily.trend,
          StrategyMarketFamily.momentum,
          StrategyMarketFamily.breakout,
          StrategyMarketFamily.volatility,
        },
      );
    }
    if (expanding || nearEdge) {
      return const MarketRoute(
        regime: RoutedMarketRegime.breakout,
        reason: 'M5 volatility/20-bar boundary expansion.',
        activeFamilies: {
          StrategyMarketFamily.breakout,
          StrategyMarketFamily.momentum,
          StrategyMarketFamily.volatility,
        },
      );
    }
    if (directional) {
      return const MarketRoute(
        regime: RoutedMarketRegime.trend,
        reason: 'H1 directional structure is dominant.',
        activeFamilies: {
          StrategyMarketFamily.trend,
          StrategyMarketFamily.pullback,
          StrategyMarketFamily.momentum,
        },
      );
    }
    if (range <= avgRange * 8) {
      return const MarketRoute(
        regime: RoutedMarketRegime.range,
        reason: '20-bar travel is compressed relative to average bar range.',
        activeFamilies: {
          StrategyMarketFamily.range,
          StrategyMarketFamily.reversal,
        },
      );
    }
    return const MarketRoute(
      regime: RoutedMarketRegime.transition,
      reason:
          'No dominant trend/range state; transition families remain relevant.',
      activeFamilies: {
        StrategyMarketFamily.transition,
        StrategyMarketFamily.reversal,
      },
    );
  }
}
