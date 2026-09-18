import 'package:flutter_test/flutter_test.dart';
import 'package:tradeforge_mobile/src/domain/signal_history_view.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 18);

  SignalHistoryView row(
    String id,
    int minute, {
    String exposure = 'independent',
    String? group,
    int? resolvedMinute,
  }) =>
      SignalHistoryView(
        id: id,
        source: 'frozen',
        symbol: 'XAUUSD',
        strategy: 'C5',
        side: 'BUY',
        observedAt: t0.add(Duration(minutes: minute)),
        entry: 4300,
        stopLoss: 4290,
        takeProfit: 4320,
        riskReward: 2,
        status: SignalHistoryStatus.targetHit,
        exposureStatus: exposure,
        exposureGroupId: group,
        independentEvidence: exposure != 'same_exposure',
        executionEligible: exposure != 'same_exposure',
        resolvedAt: resolvedMinute == null
            ? null
            : t0.add(Duration(minutes: resolvedMinute)),
      );

  test('three overlapping triggers render as one exposure group', () {
    final groups = buildSignalExposureGroups([
      row('root', 0, resolvedMinute: 60),
      row('child-1', 15, exposure: 'same_exposure', group: 'root'),
      row('child-2', 30, exposure: 'same_exposure', group: 'root'),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.root.id, 'root');
    expect(groups.single.suppressedTriggerCount, 2);
    expect(groups.single.triggerCount, 3);
  });

  test('signal after root resolved becomes a new independent group', () {
    final groups = buildSignalExposureGroups([
      row('root', 0, resolvedMinute: 20),
      row('next', 25, resolvedMinute: 45),
    ]);

    expect(groups, hasLength(2));
  });

  test('raw trigger list is not mutated by grouping', () {
    final raw = [
      row('root', 0, resolvedMinute: 60),
      row('child', 15, exposure: 'same_exposure', group: 'root'),
    ];

    final groups = buildSignalExposureGroups(raw);

    expect(raw, hasLength(2));
    expect(groups, hasLength(1));
  });
}
