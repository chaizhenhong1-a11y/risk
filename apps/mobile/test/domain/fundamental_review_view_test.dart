import 'package:flutter_test/flutter_test.dart';
import 'package:tradeforge_mobile/src/domain/signal_history_view.dart';

void main() {
  test('reads AI support and oppose percentages from API review', () {
    final review = FundamentalReviewView.fromJson({
      'risk': 'CAUTION',
      'goldBias': 'mixed',
      'summary': '重要数据临近',
      'relevantFactors': ['美国通胀数据'],
      'aiAvailable': true,
      'candidatePreserved': true,
      'aiSupportPercent': 72,
      'aiOpposePercent': 28,
    });

    expect(review.aiSupportPercent, 72);
    expect(review.aiOpposePercent, 28);
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
    expect(review.candidatePreserved, isTrue);
  });
}
