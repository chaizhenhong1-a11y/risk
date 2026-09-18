import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_exposure_control.dart';

void main() {
  const control = PaperExposureControl();
  final t0 = DateTime.utc(2026, 9, 18, 0);

  PaperExposureRecord row(
    String id,
    String strategy,
    String side,
    int startMinutes, {
    int? resolvedMinutes,
  }) => PaperExposureRecord(
    id: id,
    strategy: strategy,
    side: side,
    observedAt: t0.add(Duration(minutes: startMinutes)),
    resolvedAt: resolvedMinutes == null
        ? null
        : t0.add(Duration(minutes: resolvedMinutes)),
  );

  test('same strategy and side while active is same exposure', () {
    final result = control.classify(<PaperExposureRecord>[
      row('c5-1', 'C5', 'BUY', 0, resolvedMinutes: 60),
      row('c5-2', 'C5', 'BUY', 15, resolvedMinutes: 75),
      row('c5-3', 'C5', 'BUY', 30, resolvedMinutes: 90),
    ]);

    expect(result['c5-1']!.independentEvidence, isTrue);
    expect(result['c5-1']!.executionEligible, isTrue);
    expect(result['c5-2']!.exposureStatus, 'same_exposure');
    expect(result['c5-2']!.independentEvidence, isFalse);
    expect(result['c5-2']!.executionEligible, isFalse);
    expect(result['c5-2']!.exposureGroupId, 'c5-1');
    expect(result['c5-3']!.exposureGroupId, 'c5-1');
  });

  test('new signal after previous resolution is independent', () {
    final result = control.classify(<PaperExposureRecord>[
      row('c5-1', 'C5', 'BUY', 0, resolvedMinutes: 20),
      row('c5-2', 'C5', 'BUY', 25),
    ]);

    expect(result['c5-2']!.exposureStatus, 'independent');
    expect(result['c5-2']!.independentEvidence, isTrue);
    expect(result['c5-2']!.executionEligible, isTrue);
  });

  test(
    'cross strategy same-side overlap is preserved for portfolio review',
    () {
      final result = control.classify(<PaperExposureRecord>[
        row('c5', 'C5', 'BUY', 0, resolvedMinutes: 60),
        row('adx', 'ADX_TREND', 'BUY', 15, resolvedMinutes: 45),
      ]);

      expect(result['adx']!.exposureStatus, 'portfolio_overlap');
      expect(result['adx']!.portfolioOverlap, isTrue);
      expect(result['adx']!.independentEvidence, isTrue);
      expect(result['adx']!.executionEligible, isTrue);
    },
  );

  test('opposite side is not collapsed into same exposure', () {
    final result = control.classify(<PaperExposureRecord>[
      row('c5-buy', 'C5', 'BUY', 0, resolvedMinutes: 60),
      row('c5-sell', 'C5', 'SELL', 15, resolvedMinutes: 45),
    ]);

    expect(result['c5-sell']!.exposureStatus, 'independent');
  });

  test('exact duplicate deterministic IDs collapse before classification', () {
    final result = control.classify(<PaperExposureRecord>[
      row('same-id', 'C5', 'BUY', 0, resolvedMinutes: 60),
      row('same-id', 'C5', 'BUY', 0, resolvedMinutes: 60),
    ]);

    expect(result, hasLength(1));
    expect(result['same-id']!.independentEvidence, isTrue);
  });

  test('pending root keeps later same-strategy side in same exposure', () {
    final result = control.classify(<PaperExposureRecord>[
      row('root', 'C5', 'BUY', 0),
      row('later', 'C5', 'BUY', 120),
    ]);

    expect(result['later']!.exposureStatus, 'same_exposure');
    expect(result['later']!.executionEligible, isFalse);
  });
}
