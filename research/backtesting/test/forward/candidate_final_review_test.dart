import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/candidate_final_review.dart';

void main() {
  test('valid BUY geometry keeps execution integrity', () {
    final review = buildCandidateFinalReview(<String, Object?>{
      'side': 'BUY',
      'entry': 4300.0,
      'stopLoss': 4290.0,
      'takeProfit': 4320.0,
      'riskReward': 2.0,
    });
    expect(review.integrityOk, isTrue);
  });

  test('invalid SELL geometry blocks execution integrity only', () {
    final review = buildCandidateFinalReview(<String, Object?>{
      'side': 'SELL',
      'entry': 4300.0,
      'stopLoss': 4290.0,
      'takeProfit': 4320.0,
      'riskReward': 2.0,
    });
    expect(review.integrityOk, isFalse);
  });

  test('RR mismatch is detected', () {
    final review = buildCandidateFinalReview(<String, Object?>{
      'side': 'BUY',
      'entry': 4300.0,
      'stopLoss': 4290.0,
      'takeProfit': 4320.0,
      'riskReward': 3.0,
    });
    expect(review.integrityOk, isFalse);
  });
}
