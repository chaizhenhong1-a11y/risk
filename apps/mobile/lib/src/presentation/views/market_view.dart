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
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: TradeForgeTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.show_chart_rounded,
                    color: TradeForgeTheme.primary),
              ),
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
                          : '${state.price!.toStringAsFixed(3)}  ·  '
                              '${state.bid!.toStringAsFixed(3)} / ${state.ask!.toStringAsFixed(3)}',
                      style: const TextStyle(color: TradeForgeTheme.muted),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                label: _statusLabel(state.connection),
                live: state.connection == LiveConnectionState.live,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppSection(
          child: trade == null
              ? _Scanning(scanStrategyCount: state.scanStrategyCount)
              : _Opportunity(trade: trade),
        ),
        const SizedBox(height: 14),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已分析 ${state.evaluatedM5Count} 根 CLOSED M5  ·  '
                'A ${state.aOpportunityCount}  ·  C5 ${state.c5OpportunityCount}',
                style: const TextStyle(
                  color: TradeForgeTheme.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              _StrategyDiagnostic(
                title: 'Strategy A',
                result: state.strategyAResult,
                reason: state.strategyAReason,
                evaluatedAt: state.strategyALastEvaluatedAt,
              ),
              const SizedBox(height: 14),
              _StrategyDiagnostic(
                title: 'Strategy C5',
                result: state.strategyC5Result,
                reason: state.strategyC5Reason,
                evaluatedAt: state.strategyC5LastEvaluatedAt,
              ),
              const SizedBox(height: 14),
              for (final entry in state.segmentScans.entries) ...[
                _PaperSegmentCard(
                  title: _segmentTitle(entry.key),
                  side: _segmentPart(entry.key, 1),
                  regime: _segmentPart(entry.key, 2),
                  segmentId: entry.key,
                  scan: entry.value,
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _segmentPart(String id, int index) {
    final parts = id.split('|');
    return parts.length > index ? parts[index] : '-';
  }

  static String _segmentTitle(String id) {
    final words = _segmentPart(id, 0).toLowerCase().split('_');
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static String _statusLabel(LiveConnectionState value) => switch (value) {
        LiveConnectionState.live => '实时',
        LiveConnectionState.connecting => '连接中',
        LiveConnectionState.unavailable => '离线',
      };

  static String _connectionText(LiveConnectionState value) => switch (value) {
        LiveConnectionState.live => 'BiQuote 实时行情',
        LiveConnectionState.connecting => '正在连接 TradeForge 服务',
        LiveConnectionState.unavailable => 'TradeForge 服务未连接',
      };
}

class _Scanning extends StatelessWidget {
  const _Scanning({required this.scanStrategyCount});

  final int scanStrategyCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('当前机会',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              Icon(Icons.radar_rounded, size: 34, color: TradeForgeTheme.muted),
              SizedBox(height: 10),
              Text('正在扫描市场',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('$scanStrategyCount 个扫描源没有触发时不会制造信号',
                  style: TextStyle(color: TradeForgeTheme.muted)),
            ],
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }
}

class _Opportunity extends StatelessWidget {
  const _Opportunity({required this.trade});

  final LiveTradeView trade;

  @override
  Widget build(BuildContext context) {
    final side = trade.direction == TradeDirection.buy ? 'BUY' : 'SELL';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$side ${trade.strategy}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${trade.riskReward.toStringAsFixed(2)}R',
                style: const TextStyle(
                    color: TradeForgeTheme.primary,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 28,
          runSpacing: 12,
          children: [
            _Value(label: 'Entry', value: trade.entry),
            _Value(label: 'SL', value: trade.stopLoss),
            _Value(label: 'TP', value: trade.takeProfit),
          ],
        ),
        if (trade.reason.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(trade.reason,
              style:
                  const TextStyle(color: TradeForgeTheme.muted, height: 1.4)),
        ],
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: TradeForgeTheme.muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value.toStringAsFixed(3),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

class _StrategyDiagnostic extends StatelessWidget {
  const _StrategyDiagnostic({
    required this.title,
    required this.result,
    required this.reason,
    required this.evaluatedAt,
  });

  final String title;
  final String result;
  final String reason;
  final DateTime? evaluatedAt;

  @override
  Widget build(BuildContext context) {
    final time = evaluatedAt;
    final timeText = time == null
        ? '等待首个 M5 收盘'
        : '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}';
    final waiting = time == null || result == 'WAITING';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TradeForgeTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TradeForgeTheme.muted.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title == 'Strategy C5'
                          ? 'Transition Strategy'
                          : 'Trend Strategy',
                      style: const TextStyle(
                        color: TradeForgeTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _DiagnosticResultPill(result: result, waiting: waiting),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            reason,
            style: const TextStyle(
              color: TradeForgeTheme.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                '最后分析',
                style: TextStyle(
                  color: TradeForgeTheme.muted,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                timeText,
                style: const TextStyle(
                  color: TradeForgeTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaperSegmentCard extends StatelessWidget {
  const _PaperSegmentCard({
    required this.title,
    required this.side,
    required this.regime,
    required this.segmentId,
    required this.scan,
  });

  final String title;
  final String side;
  final String regime;
  final String segmentId;
  final StrategyScanView scan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TradeForgeTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TradeForgeTheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$side · $regime',
                      style: const TextStyle(
                        color: TradeForgeTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: TradeForgeTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'PAPER FORWARD',
                  style: TextStyle(
                    color: TradeForgeTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _DiagnosticResultPill(
                result: scan.result,
                waiting:
                    scan.lastEvaluatedAt == null || scan.result == 'WAITING',
              ),
              const Spacer(),
              Text(
                scan.lastEvaluatedAt == null
                    ? '等待首个 M5 收盘'
                    : '${scan.lastEvaluatedAt!.hour.toString().padLeft(2, '0')}:'
                        '${scan.lastEvaluatedAt!.minute.toString().padLeft(2, '0')}',
                style:
                    const TextStyle(color: TradeForgeTheme.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(scan.reason,
              style: const TextStyle(
                  color: TradeForgeTheme.muted, fontSize: 13, height: 1.45)),
          if (scan.entry != null &&
              scan.stopLoss != null &&
              scan.takeProfit != null) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 22, runSpacing: 8, children: [
              _Value(label: 'Entry', value: scan.entry!),
              _Value(label: 'SL', value: scan.stopLoss!),
              _Value(label: 'TP', value: scan.takeProfit!),
            ]),
          ],
          const SizedBox(height: 10),
          Text(segmentId,
              style: const TextStyle(
                  color: TradeForgeTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DiagnosticResultPill extends StatelessWidget {
  const _DiagnosticResultPill({required this.result, required this.waiting});

  final String result;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final isTrade = result == 'BUY' || result == 'SELL' || result == 'TRADE';
    final highlighted = isTrade && !waiting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? TradeForgeTheme.primary.withValues(alpha: 0.10)
            : TradeForgeTheme.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        result.replaceAll('_', ' '),
        style: TextStyle(
          color: highlighted ? TradeForgeTheme.primary : TradeForgeTheme.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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
              ? TradeForgeTheme.primary.withValues(alpha: 0.10)
              : TradeForgeTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: live ? TradeForgeTheme.primary : TradeForgeTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
