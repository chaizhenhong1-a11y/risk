import 'package:flutter/material.dart';

import '../../application/live_tradeforge_controller.dart';
import '../views/market_view.dart';
import '../views/performance_view.dart';
import '../views/settings_view.dart';
import '../views/signals_view.dart';

class TradeForgeShell extends StatefulWidget {
  const TradeForgeShell({super.key});

  @override
  State<TradeForgeShell> createState() => _TradeForgeShellState();
}

class _TradeForgeShellState extends State<TradeForgeShell> {
  int _index = 0;
  late final LiveTradeForgeController _liveController;

  @override
  void initState() {
    super.initState();
    _liveController = LiveTradeForgeController()..start();
  }

  @override
  void dispose() {
    _liveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _liveController,
          builder: (context, _) {
            final state = _liveController.state;
            return IndexedStack(
              index: _index,
              children: [
                MarketView(state: state),
                SignalsView(state: state),
                PerformanceView(state: state),
                const SettingsView(),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined),
            selectedIcon: Icon(Icons.candlestick_chart),
            label: '市场',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: '信号',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
