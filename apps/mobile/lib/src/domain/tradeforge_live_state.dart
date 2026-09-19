import 'live_trade_view.dart';
import 'signal_history_view.dart';

enum LiveConnectionState { connecting, live, marketClosed, unavailable }

class StrategyScanView {
  const StrategyScanView(
      {this.result = 'WAITING',
      this.reason = '等待首个 CLOSED M5。',
      this.lastEvaluatedAt,
      this.mode = 'production',
      this.entry,
      this.stopLoss,
      this.takeProfit,
      this.riskReward});
  final String result, reason, mode;
  final DateTime? lastEvaluatedAt;
  final double? entry, stopLoss, takeProfit, riskReward;
  factory StrategyScanView.fromJson(Object? raw) {
    if (raw is! Map) return const StrategyScanView();
    final j = Map<String, dynamic>.from(raw);
    return StrategyScanView(
        result: j['result']?.toString() ?? 'WAITING',
        reason: j['reason']?.toString() ?? '等待首个 CLOSED M5。',
        lastEvaluatedAt: TradeForgeLiveState._date(j['lastEvaluatedAt']),
        mode: j['mode']?.toString() ?? 'production',
        entry: (j['entry'] as num?)?.toDouble(),
        stopLoss: (j['stopLoss'] as num?)?.toDouble(),
        takeProfit: (j['takeProfit'] as num?)?.toDouble(),
        riskReward: (j['riskReward'] as num?)?.toDouble());
  }
}

class TradeForgeLiveState {
  const TradeForgeLiveState(
      {required this.connection,
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
      this.segmentScans = const {},
      this.signalHistory = const []});
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
        segmentScans = const {},
        signalHistory = const [];
  factory TradeForgeLiveState.unavailable(String error) => TradeForgeLiveState(
      connection: LiveConnectionState.unavailable, error: error);
  final LiveConnectionState connection;
  final String symbol;
  final double? bid, ask, price;
  final String? source;
  final LiveTradeView? latestTrade;
  final DateTime? lastUpdatedAt;
  final String? error;
  final int warmupM5Count,
      evaluatedM5Count,
      scanCompletedCount,
      scanStrategyCount,
      aOpportunityCount,
      c5OpportunityCount;
  final StrategyScanView strategyA, strategyC5;
  final Map<String, StrategyScanView> segmentScans;
  final List<SignalHistoryView> signalHistory;
  List<SignalExposureGroup> get exposureGroups =>
      buildSignalExposureGroups(signalHistory);
  int get independentTradeCount => exposureGroups.length;
  int get sameExposureTriggerCount =>
      signalHistory.where((x) => x.isSameExposure).length;
  String get strategyAResult => strategyA.result;
  String get strategyAReason => strategyA.reason;
  DateTime? get strategyALastEvaluatedAt => strategyA.lastEvaluatedAt;
  String get strategyC5Result => strategyC5.result;
  String get strategyC5Reason => strategyC5.reason;
  DateTime? get strategyC5LastEvaluatedAt => strategyC5.lastEvaluatedAt;
  factory TradeForgeLiveState.fromJson(Map<String, dynamic> j) {
    final q =
        j['quote'] is Map ? Map<String, dynamic>.from(j['quote'] as Map) : null;
    final s = j['strategies'] is Map
        ? Map<String, dynamic>.from(j['strategies'] as Map)
        : const <String, dynamic>{};
    final o = j['opportunity'] is Map
        ? LiveTradeView.fromJson(
            Map<String, dynamic>.from(j['opportunity'] as Map))
        : null;
    final raw = j['connection']?.toString() ?? 'disconnected';
    final ids = s.keys.where((id) => id.contains('|')).toList(growable: false);
    final h = j['signalHistory'] is List
        ? j['signalHistory'] as List
        : const <Object?>[];
    return TradeForgeLiveState(
        connection: raw == 'connected'
            ? LiveConnectionState.live
            : raw == 'marketClosed'
                ? LiveConnectionState.marketClosed
                : (raw == 'connecting' || raw == 'reconnecting'
                    ? LiveConnectionState.connecting
                    : LiveConnectionState.unavailable),
        symbol: j['symbol']?.toString() ?? 'XAUUSD',
        bid: (q?['bid'] as num?)?.toDouble(),
        ask: (q?['ask'] as num?)?.toDouble(),
        price: (q?['mid'] as num?)?.toDouble(),
        source: q?['source']?.toString(),
        latestTrade: o,
        lastUpdatedAt: _date(q?['timestamp']),
        error: j['error']?.toString(),
        warmupM5Count: (j['warmupM5Count'] as num?)?.toInt() ?? 0,
        evaluatedM5Count: (j['evaluatedM5Count'] as num?)?.toInt() ?? 0,
        scanCompletedCount: (j['scanCompletedCount'] as num?)?.toInt() ?? 0,
        scanStrategyCount: (j['scanStrategyCount'] as num?)?.toInt() ?? 6,
        aOpportunityCount: (j['aOpportunityCount'] as num?)?.toInt() ?? 0,
        c5OpportunityCount: (j['c5OpportunityCount'] as num?)?.toInt() ?? 0,
        strategyA: StrategyScanView.fromJson(s['A']),
        strategyC5: StrategyScanView.fromJson(s['C5']),
        segmentScans: {
          for (final id in ids) id: StrategyScanView.fromJson(s[id])
        },
        signalHistory: [
          for (final x in h)
            if (x is Map)
              SignalHistoryView.fromJson(Map<String, dynamic>.from(x))
        ]);
  }
  static DateTime? _date(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v)?.toLocal();
  }
}
