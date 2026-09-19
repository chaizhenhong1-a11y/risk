import 'package:flutter_test/flutter_test.dart';
import 'package:tradeforge_mobile/src/domain/signal_history_view.dart';

void main() {
  test('reads AI support and oppose percentages with explanations', () {
    final review = FundamentalReviewView.fromJson({
      'risk': 'CAUTION',
      'goldBias': 'mixed',
      'summary': '重要数据临近',
      'relevantFactors': ['美国通胀数据'],
      'aiAvailable': true,
      'candidatePreserved': true,
      'aiSupportPercent': 72,
      'aiOpposePercent': 28,
      'aiSupportExplanation': '当前策略结构提供主要支持。',
      'aiOpposeExplanation': '重要数据公布前仍有波动风险。',
    });

    expect(review.aiSupportPercent, 72);
    expect(review.aiOpposePercent, 28);
    expect(review.aiSupportExplanation, contains('支持'));
    expect(review.aiOpposeExplanation, contains('风险'));
    expect(review.candidatePreserved, isTrue);
  });

  test('missing AI percentages do not affect candidate preservation', () {
    final review = FundamentalReviewView.fromJson({
      'risk': 'NORMAL',
      'goldBias': 'unclear',
      'summary': '',
      'relevantFactors': <String>[],
      'aiAvailable': false,
      'candidatePreserved': true,
    });

    expect(review.aiSupportPercent, isNull);
    expect(review.aiOpposePercent, isNull);
    expect(review.aiSupportExplanation, isEmpty);
    expect(review.aiOpposeExplanation, isEmpty);
    expect(review.candidatePreserved, isTrue);
  });
}
