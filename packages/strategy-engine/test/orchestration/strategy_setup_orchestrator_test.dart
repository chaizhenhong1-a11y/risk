import 'package:market_models/market_models.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const orchestrator = StrategySetupOrchestrator();
  final profile = SetupScoreProfiles.baselineResearchV1;

  group('StrategySetupOrchestrator', () {
    test('integrates bullish setup from bias through snapshot and score', () {
      final analysis = orchestrator.analyze(
        h4Structure: MarketStructure.bullish,
        h1Structure: MarketStructure.bullish,
        m15Structure: MarketStructure.bullish,
        d1Structure: MarketStructure.bullish,
        closedM15Candle: _candle(
          open: 2300.5,
          high: 2302.0,
          low: 2299.0,
          close: 2301.5,
        ),
        closedM5Candle: _candle(
          open: 2301.0,
          high: 2302.0,
          low: 2300.8,
          close: 2301.8,
        ),
        keyLevels: [_support()],
        matchedLevelStrength: LevelStrength.established,
        scoreProfile: profile,
      );

      expect(analysis.bias.bias, TradingBias.buy);
      expect(analysis.pullback.hasPullback, isTrue);
      expect(analysis.confirmation.isConfirmed, isTrue);
      expect(analysis.evaluation.isEligible, isTrue);
      expect(
        analysis.snapshot.hasEvidence(
          SetupEvidenceType.directionalM15Structure,
        ),
        isTrue,
      );
      expect(
        analysis.snapshot.hasEvidence(
          SetupEvidenceType.directionalM5Confirmation,
        ),
        isTrue,
      );
      expect(analysis.snapshot.d1ContextAlignment, D1ContextAlignment.aligned);
      expect(analysis.snapshot.keyLevelQuality, KeyLevelQuality.established);
      expect(analysis.scoreProfileKey, 'baseline-research@v1');
      expect(analysis.score.earnedPoints, 80);
      expect(analysis.score.availablePoints, 100);
    });

    test(
      'higher-timeframe conflict blocks setup regardless of soft evidence',
      () {
        final analysis = orchestrator.analyze(
          h4Structure: MarketStructure.bullish,
          h1Structure: MarketStructure.bearish,
          m15Structure: MarketStructure.bullish,
          d1Structure: MarketStructure.bullish,
          closedM15Candle: _candle(
            open: 2300.5,
            high: 2302.0,
            low: 2299.0,
            close: 2301.5,
          ),
          closedM5Candle: _candle(
            open: 2301.0,
            high: 2302.0,
            low: 2300.8,
            close: 2301.8,
          ),
          keyLevels: [_support()],
          matchedLevelStrength: LevelStrength.wellTested,
          scoreProfile: profile,
        );

        expect(analysis.bias.bias, TradingBias.noTrade);
        expect(analysis.evaluation.isEligible, isFalse);
        expect(analysis.evaluation.blockReason, SetupBlockReason.noTradeBias);
      },
    );

    test('directional bias without M15 pullback is blocked', () {
      final analysis = orchestrator.analyze(
        h4Structure: MarketStructure.bullish,
        h1Structure: MarketStructure.bullish,
        m15Structure: MarketStructure.bullish,
        closedM15Candle: _candle(
          open: 2310.0,
          high: 2312.0,
          low: 2309.0,
          close: 2311.0,
        ),
        closedM5Candle: _candle(
          open: 2310.5,
          high: 2311.5,
          low: 2310.0,
          close: 2311.2,
        ),
        keyLevels: [_support()],
        scoreProfile: profile,
      );

      expect(analysis.bias.bias, TradingBias.buy);
      expect(analysis.pullback.hasPullback, isFalse);
      expect(analysis.evaluation.isEligible, isFalse);
      expect(
        analysis.evaluation.blockReason,
        SetupBlockReason.pullbackNotPresent,
      );
    });

    test('missing optional context remains explicit rather than guessed', () {
      final analysis = orchestrator.analyze(
        h4Structure: MarketStructure.bearish,
        h1Structure: MarketStructure.bearish,
        m15Structure: MarketStructure.neutral,
        closedM15Candle: _candle(
          open: 2301.5,
          high: 2302.0,
          low: 2299.0,
          close: 2299.5,
        ),
        closedM5Candle: _candle(
          open: 2300.0,
          high: 2300.5,
          low: 2299.0,
          close: 2299.2,
        ),
        keyLevels: [_resistance()],
        scoreProfile: profile,
      );

      expect(analysis.bias.bias, TradingBias.sell);
      expect(
        analysis.d1ContextEvidence.alignment,
        D1ContextAlignment.unavailable,
      );
      expect(
        analysis.keyLevelQualityEvidence.quality,
        KeyLevelQuality.unavailable,
      );
      expect(
        analysis.snapshot.hasEvidence(SetupEvidenceType.directionalLevelSweep),
        isFalse,
      );
      expect(
        analysis.snapshot.hasEvidence(SetupEvidenceType.directionalPoolSweep),
        isFalse,
      );
    });
  });
}

Candle _candle({
  required double open,
  required double high,
  required double low,
  required double close,
}) => Candle(
  openTime: DateTime.utc(2026, 9, 15, 10),
  closeTime: DateTime.utc(2026, 9, 15, 10, 15),
  open: open,
  high: high,
  low: low,
  close: close,
  volume: 100,
);

KeyLevel _support() => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: 2299.0,
  upperBound: 2301.0,
  createdAtCandleIndex: 10,
);

KeyLevel _resistance() => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: 2300.0,
  upperBound: 2301.0,
  createdAtCandleIndex: 12,
);
