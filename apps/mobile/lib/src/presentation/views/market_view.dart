import 'package:flutter/material.dart';
import '../../domain/live_trade_view.dart';
import '../../domain/tradeforge_live_state.dart';
import '../../theme/tradeforge_theme.dart';
import '../widgets/app_section.dart';
import '../widgets/page_header.dart';

class MarketView extends StatelessWidget {
  const MarketView({required this.state, super.key});
  final TradeForgeLiveState state;

  @override
  Widget build(BuildContext context) {
    final trade = state.latestTrade;
    return ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
        children: [
          const PageHeader(title: 'TradeForge', subtitle: 'XAUUSD · 实时决策辅助'),
          const SizedBox(height: 22),
          AppSection(
              child: Row(children: [
            Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: TradeForgeTheme.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.show_chart_rounded,
                    color: TradeForgeTheme.primary)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(state.symbol,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                      state.price == null
                          ? _connectionText(state.connection)
                          : '${state.price!.toStringAsFixed(3)}  ·  ${state.bid!.toStringAsFixed(3)} / ${state.ask!.toStringAsFixed(3)}',
                      style: const TextStyle(color: TradeForgeTheme.muted)),
                ])),
            _StatusPill(
                label: _statusLabel(state.connection),
                live: state.connection == LiveConnectionState.live),
          ])),
          const SizedBox(height: 14),
          AppSection(
              child: trade == null
                  ? _Scanning(
                      scanStrategyCount: state.scanStrategyCount,
                      connection: state.connection)
                  : _Opportunity(trade: trade)),
          const SizedBox(height: 14),
          AppSection(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    '已分析 ${state.evaluatedM5Count} 根 CLOSED M5  ·  A ${state.aOpportunityCount}  ·  C5 ${state.c5OpportunityCount}',
                    style: const TextStyle(
                        color: TradeForgeTheme.muted, fontSize: 12)),
                const SizedBox(height: 14),
                _StrategyDiagnostic(title: 'Strategy A', scan: state.strategyA),
                const SizedBox(height: 14),
                _StrategyDiagnostic(
                    title: 'Strategy C5', scan: state.strategyC5),
                const SizedBox(height: 14),
                for (final e in state.segmentScans.entries) ...[
                  _StrategyDiagnostic(
                      title: _segmentTitle(e.key),
                      scan: e.value,
                      subtitle:
                          '${_part(e.key, 1)} · ${_part(e.key, 2)} · PAPER FORWARD'),
                  const SizedBox(height: 14)
                ],
              ])),
        ]);
  }

  static String _part(String id, int i) {
    final p = id.split('|');
    return p.length > i ? p[i] : '-';
  }

  static String _segmentTitle(String id) => _part(id, 0)
      .toLowerCase()
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  static String _statusLabel(LiveConnectionState v) => switch (v) {
        LiveConnectionState.live => '实时',
        LiveConnectionState.connecting => '连接中',
        LiveConnectionState.marketClosed => '闭市',
        LiveConnectionState.unavailable => '离线'
      };
  static String _connectionText(LiveConnectionState v) => switch (v) {
        LiveConnectionState.live => 'BiQuote 实时行情',
        LiveConnectionState.connecting => '正在连接 TradeForge 服务',
        LiveConnectionState.marketClosed => 'XAUUSD 当前闭市 · BiQuote 服务在线',
        LiveConnectionState.unavailable => 'TradeForge / 行情服务离线'
      };
}

class _Scanning extends StatelessWidget {
  const _Scanning({required this.scanStrategyCount, required this.connection});
  final int scanStrategyCount;
  final LiveConnectionState connection;
  @override
  Widget build(BuildContext context) {
    final closed = connection == LiveConnectionState.marketClosed;
    final offline = connection == LiveConnectionState.unavailable;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('当前机会',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      Center(
          child: Column(children: [
        Icon(
            closed
                ? Icons.nights_stay_rounded
                : offline
                    ? Icons.cloud_off_rounded
                    : Icons.radar_rounded,
            size: 34,
            color: TradeForgeTheme.muted),
        const SizedBox(height: 10),
        Text(
            closed
                ? '市场已闭市'
                : offline
                    ? '行情服务离线'
                    : '正在扫描市场',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            closed
                ? '保留历史数据，不生成新的实时机会'
                : offline
                    ? '等待行情服务恢复'
                    : '$scanStrategyCount 个扫描源没有触发时不会制造信号',
            style: const TextStyle(color: TradeForgeTheme.muted)),
      ])),
      const SizedBox(height: 8),
    ]);
  }
}

class _Opportunity extends StatelessWidget {
  const _Opportunity({required this.trade});
  final LiveTradeView trade;
  @override
  Widget build(BuildContext context) {
    final side = trade.direction == TradeDirection.buy ? 'BUY' : 'SELL';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$side ${trade.strategy}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('${trade.riskReward.toStringAsFixed(2)}R',
            style: const TextStyle(
                color: TradeForgeTheme.primary, fontWeight: FontWeight.w800))
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 28, runSpacing: 12, children: [
        _Value(label: 'Entry', value: trade.entry),
        _Value(label: 'SL', value: trade.stopLoss),
        _Value(label: 'TP', value: trade.takeProfit)
      ]),
      if (trade.reason.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(trade.reason,
            style: const TextStyle(color: TradeForgeTheme.muted, height: 1.4))
      ],
    ]);
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: TradeForgeTheme.muted, fontSize: 12)),
        const SizedBox(height: 3),
        Text(value.toStringAsFixed(3),
            style: const TextStyle(fontWeight: FontWeight.w700))
      ]);
}

class _StrategyDiagnostic extends StatelessWidget {
  const _StrategyDiagnostic(
      {required this.title, required this.scan, this.subtitle});
  final String title;
  final StrategyScanView scan;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final time = scan.lastEvaluatedAt;
    final tt = time == null
        ? '等待首个 M5 收盘'
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: TradeForgeTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: TradeForgeTheme.muted.withValues(alpha: .16))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      subtitle ??
                          (title == 'Strategy C5'
                              ? 'Transition Strategy'
                              : 'Trend Strategy'),
                      style: const TextStyle(
                          color: TradeForgeTheme.muted, fontSize: 12))
                ])),
            _Result(result: scan.result)
          ]),
          const SizedBox(height: 18),
          Text(scan.reason,
              style: const TextStyle(
                  color: TradeForgeTheme.muted, fontSize: 13, height: 1.45)),
          const SizedBox(height: 18),
          Row(children: [
            const Text('最后分析',
                style: TextStyle(color: TradeForgeTheme.muted, fontSize: 12)),
            const Spacer(),
            Text(tt,
                style: const TextStyle(
                    color: TradeForgeTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))
          ]),
          if (scan.entry != null &&
              scan.stopLoss != null &&
              scan.takeProfit != null) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 22, children: [
              _Value(label: 'Entry', value: scan.entry!),
              _Value(label: 'SL', value: scan.stopLoss!),
              _Value(label: 'TP', value: scan.takeProfit!)
            ])
          ],
        ]));
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.result});
  final String result;
  @override
  Widget build(BuildContext context) {
    final hi = result == 'BUY' || result == 'SELL' || result == 'TRADE';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: hi
                ? TradeForgeTheme.primary.withValues(alpha: .10)
                : TradeForgeTheme.muted.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(99)),
        child: Text(result.replaceAll('_', ' '),
            style: TextStyle(
                color: hi ? TradeForgeTheme.primary : TradeForgeTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800)));
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.live});
  final String label;
  final bool live;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: live
              ? TradeForgeTheme.primary.withValues(alpha: .10)
              : TradeForgeTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: TextStyle(
              color: live ? TradeForgeTheme.primary : TradeForgeTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700)));
}
