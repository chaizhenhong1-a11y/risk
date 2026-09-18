import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/tradeforge_live_api.dart';
import '../domain/tradeforge_live_state.dart';

final class LiveTradeForgeController extends ChangeNotifier {
  LiveTradeForgeController({TradeForgeLiveApi? api})
      : _api = api ?? TradeForgeLiveApi();

  final TradeForgeLiveApi _api;
  TradeForgeLiveState _state = const TradeForgeLiveState.initial();
  Timer? _timer;
  bool _fetching = false;
  bool _disposed = false;

  TradeForgeLiveState get state => _state;

  void start() {
    if (_timer != null) return;
    unawaited(_refresh());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refresh()),
    );
  }

  Future<void> _refresh() async {
    if (_fetching || _disposed) return;
    _fetching = true;
    try {
      _state = await _api.fetch();
    } catch (error) {
      _state = TradeForgeLiveState.unavailable('$error');
    } finally {
      _fetching = false;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _api.close();
    super.dispose();
  }
}
