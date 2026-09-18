import 'live_trade_view.dart';
import 'signal_history_view.dart';

enum LiveConnectionState { connecting, live, unavailable }

class StrategyScanView {
  const StrategyScanView({
    this.result = 'WAITING',
    this.reason = '等待首个 CLOSED M5。',
    this.lastEvaluatedAt,
    this.mode = 'production',
    this.entry,
    this.stopLoss,
    this.takeProfit,
    this.riskReward,
  });

  final String result;
  final String reason;
  final DateTime? lastEvaluatedAt;
  final String mode;
  final double? entry;
  final double? stopLoss;
  final double? takeProfit;
  final double? riskReward;

  factory StrategyScanView.fromJson(Object? raw) {
    if (raw is! Map) return const StrategyScanView();
    final json = Map<String, dynamic>.from(raw);
    return StrategyScanView(
      result: json['result']?.toString() ?? 'WAITING',
      reason: json['reason']?.toString() ?? '等待首个 CLOSED M5。',
      lastEvaluatedAt: TradeForgeLiveState._date(json['lastEvaluatedAt']),
      mode: json['mode']?.toString() ?? 'production',
      entry: (json['entry'] as num?)?.toDouble(),
      stopLoss: (json['stopLoss'] as num?)?.toDouble(),
      takeProfit: (json['takeProfit'] as num?)?.toDouble(),
      riskReward: (json['riskReward'] as num?)?.toDouble(),
    );
  }
}

class TradeForgeLiveState {
  const TradeForgeLiveState({
    required this.connection,
    this.symbol = 'XAUUSD',
    this.bid,
    this.ask,
    this.price,
    this.source,
    this.latestTrade,
    this.lastUpdatedAt,
    this.error,
    this.warmupM5Count = 0,
    this.evaluatedM5Count = 0,
    this.scanCompletedCount = 0,
    this.scanStrategyCount = 6,
    this.aOpportunityCount = 0,
    this.c5OpportunityCount = 0,
    this.strategyA = const StrategyScanView(),
    this.strategyC5 = const StrategyScanView(),
    this.segmentScans = const <String, StrategyScanView>{},
    this.signalHistory = const <SignalHistoryView>[],
  });

  const TradeForgeLiveState.initial()
      : connection = LiveConnectionState.connecting,
        symbol = 'XAUUSD',
        bid = null,
        ask = null,
        price = null,
        source = null,
        latestTrade = null,
        lastUpdatedAt = null,
        error = null,
        warmupM5Count = 0,
        evaluatedM5Count = 0,
        scanCompletedCount = 0,
        scanStrategyCount = 6,
        aOpportunityCount = 0,
        c5OpportunityCount = 0,
        strategyA = const StrategyScanView(),
        strategyC5 = const StrategyScanView(),
        segmentScans = const <String, StrategyScanView>{},
        signalHistory = const <SignalHistoryView>[];

  factory TradeForgeLiveState.unavailable(String error) => TradeForgeLiveState(
      connection: LiveConnectionState.unavailable, error: error);

  final LiveConnectionState connection;
  final String symbol;
  final double? bid, ask, price;
  final String? source;
  final LiveTradeView? latestTrade;
  final DateTime? lastUpdatedAt;
  final String? error;
  final int warmupM5Count, evaluatedM5Count;
  final int scanCompletedCount, scanStrategyCount;
  final int aOpportunityCount, c5OpportunityCount;
  final StrategyScanView strategyA, strategyC5;
  final Map<String, StrategyScanView> segmentScans;
  final List<SignalHistoryView> signalHistory;

  List<SignalExposureGroup> get exposureGroups =>
      buildSignalExposureGroups(signalHistory);

  int get independentTradeCount => exposureGroups.length;

  int get sameExposureTriggerCount =>
      signalHistory.where((item) => item.isSameExposure).length;

  String get strategyAResult => strategyA.result;
  String get strategyAReason => strategyA.reason;
  DateTime? get strategyALastEvaluatedAt => strategyA.lastEvaluatedAt;
  String get strategyC5Result => strategyC5.result;
  String get strategyC5Reason => strategyC5.reason;
  DateTime? get strategyC5LastEvaluatedAt => strategyC5.lastEvaluatedAt;

  factory TradeForgeLiveState.fromJson(Map<String, dynamic> json) {
    final quote = json['quote'] is Map
        ? Map<String, dynamic>.from(json['quote'] as Map)
        : null;
    final strategies = json['strategies'] is Map
        ? Map<String, dynamic>.from(json['strategies'] as Map)
        : const <String, dynamic>{};
    final opportunity = json['opportunity'] is Map
        ? LiveTradeView.fromJson(
            Map<String, dynamic>.from(json['opportunity'] as Map))
        : null;
    final raw = json['connection']?.toString() ?? 'disconnected';
    final segmentIds =
        strategies.keys.where((id) => id.contains('|')).toList(growable: false);
    final historyRaw = json['signalHistory'] is List
        ? json['signalHistory'] as List
        : const <Object?>[];
    return TradeForgeLiveState(
      connection: raw == 'connected'
          ? LiveConnectionState.live
          : (raw == 'connecting' || raw == 'reconnecting'
              ? LiveConnectionState.connecting
              : LiveConnectionState.unavailable),
      symbol: json['symbol']?.toString() ?? 'XAUUSD',
      bid: (quote?['bid'] as num?)?.toDouble(),
      ask: (quote?['ask'] as num?)?.toDouble(),
      price: (quote?['mid'] as num?)?.toDouble(),
      source: quote?['source']?.toString(),
      latestTrade: opportunity,
      lastUpdatedAt: _date(quote?['timestamp']),
      error: json['error']?.toString(),
      warmupM5Count: (json['warmupM5Count'] as num?)?.toInt() ?? 0,
      evaluatedM5Count: (json['evaluatedM5Count'] as num?)?.toInt() ?? 0,
      scanCompletedCount: (json['scanCompletedCount'] as num?)?.toInt() ?? 0,
      scanStrategyCount: (json['scanStrategyCount'] as num?)?.toInt() ?? 6,
      aOpportunityCount: (json['aOpportunityCount'] as num?)?.toInt() ?? 0,
      c5OpportunityCount: (json['c5OpportunityCount'] as num?)?.toInt() ?? 0,
      strategyA: StrategyScanView.fromJson(strategies['A']),
      strategyC5: StrategyScanView.fromJson(strategies['C5']),
      segmentScans: {
        for (final id in segmentIds)
          id: StrategyScanView.fromJson(strategies[id]),
      },
      signalHistory: [
        for (final item in historyRaw)
          if (item is Map)
            SignalHistoryView.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
