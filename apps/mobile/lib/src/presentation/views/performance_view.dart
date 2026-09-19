import 'package:flutter/material.dart';

import '../../domain/performance_view.dart';
import '../../domain/signal_history_view.dart';
import '../../domain/tradeforge_live_state.dart';
import '../../theme/tradeforge_theme.dart';
import '../widgets/app_section.dart';
import '../widgets/page_header.dart';

class PerformanceView extends StatelessWidget {
  const PerformanceView({required this.state, super.key});

  final TradeForgeLiveState state;

  @override
  Widget build(BuildContext context) {
    final production = state.signalHistory.where((x) => !x.isPaperForward);
    final paper = state.signalHistory.where((x) => x.isPaperForward);
    final productionMetrics = PerformanceMetricsView.fromHistory(production);
    final paperMetrics = PerformanceMetricsView.fromHistory(paper);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 20, 18, 12),
            child: PageHeader(
              title: '策略统计',
              subtitle: 'Production / Paper / Historical 严格分离',
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: _PerformanceTabs(),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                _ForwardPerformancePage(
                  title: 'Production Forward',
                  subtitle: 'A / C5 · 正式系统信号',
                  metrics: productionMetrics,
                  history: production,
                  emptyText: '目前没有已完成的 Production Forward 交易',
                ),
                _ForwardPerformancePage(
                  title: 'Paper Forward',
                  subtitle: '冻结 Paper 策略 · 模拟验证，不计入正式总胜率',
                  metrics: paperMetrics,
                  history: paper,
                  emptyText: '目前没有已完成的 Paper Forward 交易',
                ),
                const _HistoricalPerformancePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceTabs extends StatelessWidget {
  const _PerformanceTabs();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: TradeForgeTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TradeForgeTheme.border),
        ),
        child: const TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: 'Production'),
            Tab(text: 'Paper'),
            Tab(text: 'Historical'),
          ],
        ),
      );
}

class _ForwardPerformancePage extends StatelessWidget {
  const _ForwardPerformancePage({
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.history,
    required this.emptyText,
  });

  final String title;
  final String subtitle;
  final PerformanceMetricsView metrics;
  final Iterable<SignalHistoryView> history;
  final String emptyText;

  @override
  Widget build(BuildContext context) => ListView(
        key: PageStorageKey<String>(title),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _OverallCard(label: title, metrics: metrics),
          const SizedBox(height: 22),
          _SectionTitle(title, subtitle),
          const SizedBox(height: 10),
          _ForwardStrategyList(history: history, emptyText: emptyText),
        ],
      );
}

class _HistoricalPerformancePage extends StatelessWidget {
  const _HistoricalPerformancePage();

  @override
  Widget build(BuildContext context) => ListView(
        key: const PageStorageKey<String>('Historical'),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          const _SectionTitle(
            'Production Strategy Baseline',
            '2024–2026 · A / C5 固定历史基线',
          ),
          const SizedBox(height: 10),
          for (final item in historicalPerformanceBaseline.where(
            (item) => item.strategy != 'B',
          )) ...[
            _HistoricalCard(item: item),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          const _SectionTitle(
            'Research Baseline',
            'Strategy B · 研究证据，样本不足',
          ),
          const SizedBox(height: 10),
          _HistoricalCard(
            item: historicalPerformanceBaseline.firstWhere(
              (item) => item.strategy == 'B',
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle(
            'Frozen Paper Historical',
            '8 个冻结 Segment · Historical evidence only',
          ),
          const SizedBox(height: 10),
          for (final item in historicalPaperSegmentBaseline) ...[
            _HistoricalPaperCard(item: item),
            const SizedBox(height: 10),
          ],
        ],
      );
}

class _HistoricalPaperCard extends StatefulWidget {
  const _HistoricalPaperCard({required this.item});

  final HistoricalPaperSegmentSnapshot item;

  @override
  State<_HistoricalPaperCard> createState() => _HistoricalPaperCardState();
}

class _HistoricalPaperCardState extends State<_HistoricalPaperCard> {
  bool _expanded = false;

  HistoricalPaperSegmentSnapshot get item => widget.item;

  @override
  Widget build(BuildContext context) => AppSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.strategy.replaceAll('_', ' '),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.side} · ${item.regime}',
                            style: const TextStyle(
                              color: TradeForgeTheme.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: TradeForgeTheme.muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(label: 'Trades', value: '${item.trades}'),
                _Metric(label: 'W / L', value: '${item.wins} / ${item.losses}'),
                _Metric(
                  label: 'Win',
                  value: '${item.winRate.toStringAsFixed(2)}%',
                ),
                _Metric(
                  label: 'E',
                  value:
                      '${item.expectancyR >= 0 ? '+' : ''}${item.expectancyR.toStringAsFixed(3)}R',
                ),
                _Metric(
                  label: 'PF',
                  value: item.profitFactor.toStringAsFixed(3),
                ),
                _Metric(
                  label: 'Total',
                  value:
                      '${item.totalR >= 0 ? '+' : ''}${item.totalR.toStringAsFixed(0)}R',
                ),
                _Metric(
                  label: 'Max DD',
                  value: '${item.maxDrawdownR.toStringAsFixed(0)}R',
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 14),
              for (final year in item.yearly) ...[
                _HistoricalYearRow(item: year),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      );
}

class _HistoricalYearRow extends StatelessWidget {
  const _HistoricalYearRow({required this.item});

  final HistoricalPaperYearSnapshot item;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TradeForgeTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TradeForgeTheme.border),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 5,
          children: [
            Text('${item.year}',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('${item.trades} trades'),
            Text('${item.winRate.toStringAsFixed(2)}%'),
            Text(
                'E ${item.expectancyR >= 0 ? '+' : ''}${item.expectancyR.toStringAsFixed(3)}R'),
            Text('PF ${item.profitFactor.toStringAsFixed(3)}'),
            Text('DD ${item.maxDrawdownR.toStringAsFixed(0)}R'),
          ],
        ),
      );
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.label, required this.metrics});

  final String label;
  final PerformanceMetricsView metrics;

  @override
  Widget build(BuildContext context) => AppSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Performance',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '$label 独立统计，不与其他证据层混算。',
              style: const TextStyle(
                color: TradeForgeTheme.muted,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            _OverallLayer(label: label, metrics: metrics),
          ],
        ),
      );
}

class _OverallLayer extends StatelessWidget {
  const _OverallLayer({required this.label, required this.metrics});

  final String label;
  final PerformanceMetricsView metrics;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Metric(label: '交易', value: '${metrics.trades}'),
              _Metric(label: '总胜率', value: _percent(metrics.winRate)),
              _Metric(label: '总 R', value: _r(metrics.totalR)),
              _Metric(label: 'E', value: _r(metrics.expectancyR)),
              _Metric(label: 'Max DD', value: _r(metrics.maxDrawdownR)),
            ],
          ),
        ],
      );

  static String _percent(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(2)}%';

  static String _r(double? value) {
    if (value == null) return '—';
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}R';
  }
}

class _ForwardStrategyList extends StatelessWidget {
  const _ForwardStrategyList({
    required this.history,
    required this.emptyText,
  });

  final Iterable<SignalHistoryView> history;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<SignalHistoryView>>{};
    for (final item in history) {
      if (item.realizedR == null) continue;
      grouped.putIfAbsent(item.strategy, () => []).add(item);
    }

    if (grouped.isEmpty) {
      return AppSection(
        child: Text(
          emptyText,
          style: const TextStyle(color: TradeForgeTheme.muted),
        ),
      );
    }

    final ids = grouped.keys.toList()..sort();
    return Column(
      children: [
        for (final id in ids) ...[
          _ForwardCard(
            strategy: id,
            metrics: PerformanceMetricsView.fromHistory(grouped[id]!),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ForwardCard extends StatelessWidget {
  const _ForwardCard({required this.strategy, required this.metrics});

  final String strategy;
  final PerformanceMetricsView metrics;

  @override
  Widget build(BuildContext context) => AppSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strategy,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  metrics.trades < 30 ? 'INSUFFICIENT SAMPLE' : 'SAMPLE ≥ 30',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(label: 'Trades', value: '${metrics.trades}'),
                _Metric(
                  label: 'W / L',
                  value: '${metrics.wins} / ${metrics.losses}',
                ),
                _Metric(
                  label: 'Win',
                  value: metrics.winRate == null
                      ? '—'
                      : '${metrics.winRate!.toStringAsFixed(2)}%',
                ),
                _Metric(
                  label: 'E',
                  value: metrics.expectancyR == null
                      ? '—'
                      : '${metrics.expectancyR! >= 0 ? '+' : ''}${metrics.expectancyR!.toStringAsFixed(2)}R',
                ),
                _Metric(
                  label: 'Total',
                  value:
                      '${metrics.totalR >= 0 ? '+' : ''}${metrics.totalR.toStringAsFixed(2)}R',
                ),
                _Metric(
                  label: 'Max DD',
                  value: '${metrics.maxDrawdownR.toStringAsFixed(2)}R',
                ),
              ],
            ),
          ],
        ),
      );
}

class _HistoricalCard extends StatelessWidget {
  const _HistoricalCard({required this.item});

  final HistoricalPerformanceSnapshot item;

  @override
  Widget build(BuildContext context) => AppSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Strategy ${item.strategy}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  item.note,
                  style: const TextStyle(
                    color: TradeForgeTheme.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(label: 'Trades', value: '${item.trades}'),
                _Metric(label: 'W / L', value: '${item.wins} / ${item.losses}'),
                _Metric(
                  label: 'Win',
                  value: '${item.winRate.toStringAsFixed(2)}%',
                ),
                _Metric(
                  label: 'E',
                  value:
                      '${item.expectancyR >= 0 ? '+' : ''}${item.expectancyR.toStringAsFixed(3)}R',
                ),
                _Metric(
                  label: 'PF',
                  value: item.profitFactor.toStringAsFixed(3),
                ),
              ],
            ),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 88),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: TradeForgeTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TradeForgeTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: TradeForgeTheme.muted,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: TradeForgeTheme.muted,
              fontSize: 11.5,
            ),
          ),
        ],
      );
}
