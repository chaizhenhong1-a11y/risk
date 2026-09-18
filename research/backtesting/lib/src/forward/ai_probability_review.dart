import 'dart:convert';

/// Immutable candidate/context sent to the AI probability reviewer.
///
/// This layer never decides whether a strategy candidate exists. It only
/// reviews a candidate that has already been produced by a frozen/research
/// strategy and exposure control.
final class AiProbabilityReviewRequest {
  const AiProbabilityReviewRequest({
    required this.signalId,
    required this.symbol,
    required this.strategy,
    required this.side,
    required this.observedAt,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.rewardRisk,
    required this.marketContext,
    this.exposureStatus = 'independent',
  });

  final String signalId;
  final String symbol;
  final String strategy;
  final String side;
  final DateTime observedAt;
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final double rewardRisk;
  final String exposureStatus;
  final Map<String, Object?> marketContext;

  Map<String, Object?> toJson() => <String, Object?>{
    'signalId': signalId,
    'symbol': symbol,
    'strategy': strategy,
    'side': side,
    'observedAt': observedAt.toUtc().toIso8601String(),
    'entry': entry,
    'stopLoss': stopLoss,
    'takeProfit': takeProfit,
    'rewardRisk': rewardRisk,
    'exposureStatus': exposureStatus,
    'marketContext': marketContext,
  };
}

enum AiReviewAvailability { available, unavailable }

enum AiConfidenceBand { standard, strong, highConviction, uncalibrated }

final class AiProbabilityReview {
  const AiProbabilityReview({
    required this.availability,
    required this.model,
    this.estimatedWinProbability,
    this.uncertainty,
    this.expectedR,
    this.confidence = AiConfidenceBand.uncalibrated,
    this.marketRegime,
    this.summary,
    this.riskFlags = const <String>[],
    this.error,
  });

  final AiReviewAvailability availability;
  final String model;
  final double? estimatedWinProbability;
  final double? uncertainty;
  final double? expectedR;
  final AiConfidenceBand confidence;
  final String? marketRegime;
  final String? summary;
  final List<String> riskFlags;
  final String? error;

  bool get isAvailable => availability == AiReviewAvailability.available;

  Map<String, Object?> toJson() => <String, Object?>{
    'availability': availability.name,
    'model': model,
    'estimatedWinProbability': estimatedWinProbability,
    'uncertainty': uncertainty,
    'expectedR': expectedR,
    'confidence': confidence.name,
    'marketRegime': marketRegime,
    'summary': summary,
    'riskFlags': riskFlags,
    'error': error,
  };

  factory AiProbabilityReview.unavailable(String model, Object error) =>
      AiProbabilityReview(
        availability: AiReviewAvailability.unavailable,
        model: model,
        error: '$error',
      );

  factory AiProbabilityReview.fromModelJson({
    required String model,
    required Map<String, dynamic> json,
    required double rewardRisk,
  }) {
    final probability = _bounded(json['estimatedWinProbability'], 0, 1);
    final uncertainty = _bounded(json['uncertainty'], 0, 0.5);
    final expectedR = probability == null
        ? null
        : probability * rewardRisk - (1 - probability);
    final rawFlags = json['riskFlags'];
    return AiProbabilityReview(
      availability: AiReviewAvailability.available,
      model: model,
      estimatedWinProbability: probability,
      uncertainty: uncertainty,
      // Expected R is calculated deterministically by TradeForge, never trusted
      // from the language model.
      expectedR: expectedR,
      // Until calibration exists, the model is not allowed to promote its own
      // probability into lot-sizing confidence.
      confidence: AiConfidenceBand.uncalibrated,
      marketRegime: json['marketRegime']?.toString(),
      summary: json['summary']?.toString(),
      riskFlags: rawFlags is List
          ? rawFlags.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }

  static double? _bounded(Object? raw, double min, double max) {
    if (raw is! num) return null;
    final value = raw.toDouble();
    if (!value.isFinite || value < min || value > max) return null;
    return value;
  }
}

String buildAiProbabilityPrompt(AiProbabilityReviewRequest request) =>
    '''
You are the probability-review layer of TradeForge. The strategy candidate
already exists. Do NOT reject, suppress, invent, or replace the candidate.
Estimate P(TP before SL) under the supplied current market context.
Do not claim certainty. Do not infer missing data. Repeated/overlapping signals
must not increase probability merely because they repeat.

Candidate/context JSON:
${jsonEncode(request.toJson())}

Return JSON only with exactly these semantic fields:
{
  "estimatedWinProbability": number from 0 to 1,
  "uncertainty": number from 0 to 0.5,
  "marketRegime": string,
  "summary": concise string,
  "riskFlags": array of strings
}
''';
