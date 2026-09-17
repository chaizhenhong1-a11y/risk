final class StrategyValidationStandard {
  const StrategyValidationStandard({
    this.minimumResolvedTrades = 30,
    this.requirePositiveNetExpectancy = true,
    this.requireProfitFactorAboveOne = true,
    this.requirePositiveFirstHalf = true,
    this.requirePositiveSecondHalf = true,
  });

  final int minimumResolvedTrades;
  final bool requirePositiveNetExpectancy;
  final bool requireProfitFactorAboveOne;
  final bool requirePositiveFirstHalf;
  final bool requirePositiveSecondHalf;
}
