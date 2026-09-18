import 'biquote_market_data.dart';
import 'biquote_signalr_client.dart';
import 'frozen_live_a_c5_evaluator.dart';
import 'paper_strategy_opportunity.dart';
import '../strategy_library/market_regime_router.dart';
import '../strategy_library/research_strategy_scanner.dart';

/// Read-only projection exposed to the Flutter client.
final class LiveTradeForgeStatus {
  const LiveTradeForgeStatus({
    required this.streamState,
    required this.evaluatedM5Count,
    required this.aOpportunityCount,
    required this.c5OpportunityCount,
    this.tick,
    this.lastEvaluation,
    this.latestOpportunity,
    this.marketRoute,
    this.researchStrategies = const [],
    this.error,
  });

  final BiQuoteStreamState streamState;
  final BiQuoteTick? tick;
  final FrozenLiveAC5Evaluation? lastEvaluation;
  final PaperStrategyOpportunity? latestOpportunity;
  final int evaluatedM5Count;
  final int aOpportunityCount;
  final int c5OpportunityCount;
  final MarketRoute? marketRoute;
  final List<ResearchStrategyObservation> researchStrategies;
  final String? error;

  Map<String, Object?> toJson() {
    final quote = tick;
    final evaluation = lastEvaluation;
    final opportunity = latestOpportunity;

    return <String, Object?>{
      'connection': streamState.name,
      'symbol': quote?.symbol ?? 'XAUUSD',
      'quote': quote == null
          ? null
          : <String, Object?>{
              'bid': quote.bid,
              'ask': quote.ask,
              'mid': quote.mid,
              'timestamp': quote.timestamp.toIso8601String(),
              'source': quote.source,
            },
      'lastClosedM5': evaluation?.observedAt.toIso8601String(),
      'diagnostics': <String, Object?>{
        'evaluatedM5': evaluatedM5Count,
        'aOpportunities': aOpportunityCount,
        'c5Opportunities': c5OpportunityCount,
      },
      'marketRegime': marketRoute == null
          ? null
          : <String, Object?>{
              'name': marketRoute!.regime.name,
              'reason': marketRoute!.reason,
            },
      'strategyLibrary': <String, Object?>{
        'total': 2 + researchStrategies.length,
        'production': 2,
        'research': researchStrategies.length,
        'researchStrategies': researchStrategies
            .map((s) => s.toJson())
            .toList(growable: false),
      },
      'strategies': <String, Object?>{
        'A': <String, Object?>{
          'status': evaluation?.aDiagnostic.result ?? 'WAITING',
          'reason': evaluation?.aDiagnostic.reason ?? '等待首个 CLOSED M5。',
          'lastEvaluatedAt': evaluation?.observedAt.toIso8601String(),
        },
        'C5': <String, Object?>{
          'status': evaluation?.c5Diagnostic.result ?? 'WAITING',
          'reason': evaluation?.c5Diagnostic.reason ?? '等待首个 CLOSED M5。',
          'lastEvaluatedAt': evaluation?.observedAt.toIso8601String(),
        },
      },
      'opportunity': opportunity == null
          ? null
          : <String, Object?>{
              'symbol': opportunity.symbol,
              'strategy': opportunity.strategy,
              'side': opportunity.side.name,
              'observedAt': opportunity.observedAt.toIso8601String(),
              'entry': opportunity.entry,
              'stopLoss': opportunity.stopLoss,
              'takeProfit': opportunity.takeProfit,
              'riskReward': _riskReward(opportunity),
              'reason': opportunity.reason,
            },
      'error': error,
    };
  }

  static double _riskReward(PaperStrategyOpportunity opportunity) {
    final risk = (opportunity.entry - opportunity.stopLoss).abs();
    if (risk == 0) return 0;
    return (opportunity.takeProfit - opportunity.entry).abs() / risk;
  }
}
