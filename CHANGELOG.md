# Changelog

### Phase 7 — Increment 089 Strategy B replay optimization and risk-funnel diagnostics

- Optimized the independent Strategy B risk replay by skipping the expensive higher-timeframe candidate reconstruction on M5-only closes where H4/H1/M15 visible history did not advance.
- The optimization is deliberately event-preserving: every H4/H1/M15 history advance is still evaluated, higher-timeframe candles remain visible only after close, and Strategy B candidate/risk/lifecycle rules are unchanged.
- Added Strategy B candidate direction diagnostics (BUY/SELL) and descriptive distributions for raw planned RR, below-minimum RR, Entry-to-SL distance, Entry-to-TP distance, and both distances normalized by visible closed-M15 ATR.
- Diagnostics are designed to explain the verified Increment 088 `203 -> 12 -> 4` funnel before any Strategy B v2 rule change; they do not lower the 2.0 minimum-RR Gate or tune Entry/SL/TP.
- Full-history acceptance requires the Increment 088 baseline counts to remain exact: 203 candidate events, 12 risk-eligible/plans, 191 below-minimum-RR blocks, 4 triggered resolved trades, 0 wins and 4 losses.
- Performance acceptance is measured separately from correctness; no fixed speed claim is encoded because runtime depends on the machine.

### Phase 7 — Increment 088 Strategy B directional-level risk plan and independent lifecycle backtest

- Added a Strategy-B-compatible directional-level risk adapter without changing the frozen Strategy A risk pipeline.
- Strategy B research Entry Zone policy is explicit: after an eligible M15 realignment event, BUY selects the nearest active M15 support at/below the trigger price and SELL selects the nearest active M15 resistance at/above it; no level is invented when none exists.
- Reuses the frozen Phase 5 structural invalidation, ATR protective buffer, nearest opposing structure target, RR calculation, and configurable minimum-RR Gate.
- Added cached ATR evaluation for the independent Strategy B risk replay; only visible closed higher-timeframe history is used.
- Added an independent Strategy B lifecycle runner using the existing READY -> TRIGGERED -> TP/SL and INVALIDATED/EXPIRED semantics, including no TP/SL monitoring on the trigger candle and no terminal-candle reuse.
- Added Strategy B terminal metrics: candidate events, risk eligibility/block reasons, plans, triggered trades, wins/losses, win rate, average planned RR, expectancy R, profit factor, and trades per observed trading date.
- Directional sweep remains soft evidence only and is not promoted to a Gate.
- This is an explicit uncalibrated research policy; it does not change Strategy A, claim profitability, or include spread/slippage/commission.

### Phase 7 — Increment 087 Strategy B v1 specification and independent candidate replay foundation

- Added the first deterministic Strategy B family, `Correction Continuation`, without modifying Strategy A rules.
- Strategy B v1 hard requirements are: H4-trend/H1-correction regime plus an event-based M15 realignment back toward the retained H4 direction.
- Preserved Increment 086 evidence: directional level/pool sweep is recorded as soft evidence and is not promoted to a hard Gate.
- Added explicit BUY/SELL research-candidate analysis for bullish/bearish correction realignment; persistent M15 alignment does not emit repeated candidates.
- Preserved the Increment 086 episode-entry contract: a newly entered correction episode may qualify when M15 is already aligned with H4.
- Registered Strategy B with `MarketRegimeRouter` only for `higherTimeframeTrendLowerTimeframeCorrection`; Strategy A remains exclusive to `trendAligned`.
- Added an independent historical Strategy B candidate replay that reuses already-visible H4/H1/M15 and Level/Liquidity facts but does not reuse Strategy A eligibility, score, pullback, risk plan, or lifecycle decisions.
- Increment 087 intentionally stops before Strategy B Entry/SL/TP/RR and terminal-trade simulation. Those require a Strategy-B-specific risk adapter and independent backtest in the next increment.
- No Strategy A Gate/Evidence, score, risk, RR, Entry, SL/TP, lifecycle, concurrency, or historical baseline behavior is changed.

### Phase 7 — Increment 086 Strategy B correction outcome research

- Added research-only forward-outcome diagnostics for four correction-regime hypotheses: M15 realignment with H4, directional sweep, sweep + simultaneous M15 realignment, and sweep followed later by M15 realignment.
- Trigger detection is event-based and uses only facts visible at the current M5 close; persistent conditions are not counted once per M5 candle.
- Forward outcomes exclude the trigger candle and measure 12/24/48-M5 MFE and MAE normalized by closed-M15 ATR(14).
- Added barrier-order diagnostics for +1 ATR vs -1 ATR and +2 ATR vs -1 ATR; same-candle conflicts are explicitly classified as ambiguous rather than guessing intrabar order.
- End-of-dataset incomplete forward windows are discarded rather than treated as resolved outcomes.
- ATR research calculation uses only the latest required closed M15 window and refreshes only when M15 history advances, avoiding full-history ATR rescans on every M5 observation.
- This increment does not create Strategy B, route correction regimes to live candidate generation, or change Strategy A, Gate/Evidence, score, risk, RR, Entry, SL/TP, lifecycle, or concurrency behavior.

### Phase 7 — Increment 085 correction-regime historical research

- Added research-only diagnostics for `higherTimeframeTrendLowerTimeframeCorrection` before defining Strategy B rules.
- Measures bullish/bearish correction observations and episodes, maximum episode duration, M15 structure distribution, M15 alignment/opposition to the H4 direction, and directional M15 level/pool sweep occurrence.
- Exposed the already-computed historical M15 structure on `StrategySetupReplayResult` so diagnostics reuse frozen replay facts instead of recalculating or looking ahead.
- Integrated the diagnostics into the real XAUUSD lifecycle runner while leaving candidate eligibility and lifecycle behavior untouched.
- This increment does not create Strategy B, route correction regimes to a strategy, tune thresholds, or change Strategy A, score, risk, RR, Entry, SL/TP, concurrency, or lifecycle rules.
- The diagnostic output is descriptive evidence only; it is not a profitability claim or an entry rule.

### Phase 7 — Increment 084 market regime router foundation

- Added a deterministic `MarketRegimeRouter` contract that maps an already-classified market regime to strategy families allowed to evaluate that context.
- Registered only the existing Strategy A (`trendPullbackStructureConfirmation`) and only for `trendAligned`; bullish/bearish direction remains supplied by the frozen regime analysis.
- Correction, range, transition, and unknown currently route to an empty strategy set because no independently backtested strategy family exists for those regimes yet.
- Empty routing means no strategy is currently registered for the regime; it does not redefine the regime as inherently untradeable.
- Added immutable route results and unit coverage for bullish/bearish trends, correction, range, transition, unknown, and route-set immutability.
- Foundation only: no Strategy A Gate/Evidence, score, risk, RR, lifecycle, Entry, SL/TP, concurrency, backtest candidate eligibility, or historical baseline behavior changed.

### Phase 7 — Increment 083 incremental market-structure replay cache

- Replaced repeated full-history swing reconstruction on every newly closed M15/H1/H4 candle with a replay-local incremental market-structure cache.
- The cache evaluates only pivots that have just become confirmable under the frozen 2-left / 2-right rule while retaining all previously confirmed swings for Level/Liquidity analysis.
- Added prefix-by-prefix equivalence coverage against the frozen `MarketStructureAnalyzer`, plus safe rebuild coverage if a supplied history shrinks.
- Preserves anti-look-ahead semantics: a pivot is still emitted only after both required right-side closed candles exist.
- Performance-only increment: no Strategy A, Market Regime, Gate/Evidence, score, risk, RR, lifecycle, Entry, SL/TP, concurrency, or research parameter behavior changed.
- Full-history acceptance remains strict: Increment 081 regime counts and the verified trading baseline must remain exactly unchanged before the performance series is frozen.

### Phase 7 — Increment 082 zero-copy historical feed optimization

- Replaced per-observation copying of all visible M5/M15/H1/H4 history lists with immutable frozen-prefix views over the existing replay buffers.
- Each historical observation freezes its visible length, so later candles remain inaccessible and the existing anti-look-ahead contract is preserved.
- Keeps externally supplied observation histories immutable while avoiding the O(history length) copy previously performed four times on every M5 replay step.
- Performance-only increment: no Strategy A, Market Regime classification, Gate/Evidence, score, risk, RR, lifecycle, concurrency, Entry, SL/TP, or research parameter behavior changed.
- Full-history acceptance remains strict: all Increment 081 regime counts and Increment 079/081 trading baseline outputs must remain exactly unchanged before this increment can be frozen.

### Phase 7 — Increment 081 market regime historical diagnostics

- Added observation-level historical diagnostics for the frozen Increment 080 `MarketRegimeClassifier` across the real XAUUSD replay.
- Reports observation count, share, consecutive regime episodes, average episode length in M5 observations, and maximum episode length for every regime state.
- Uses the already-computed H4/H1 market structures from the Strategy A replay path, preserving the existing no-look-ahead higher-timeframe close rules and replay cache.
- Does not invent range evidence: because no range detector exists yet, `range` remains zero unless explicit evidence is wired in a future increment; neutral non-unknown structure remains `transition`.
- Diagnostics only: no Strategy A Gate/Evidence, score, risk, minimum RR, lifecycle, concurrency, Entry, SL/TP, or candidate eligibility behavior changed.

### Phase 7 — Increment 080 market regime foundation

- Added a deterministic `MarketRegimeClassifier` contract for future multi-strategy routing without changing Strategy A.
- Added `trendAligned`, `higherTimeframeTrendLowerTimeframeCorrection`, `range`, `transition`, and `unknown` regime states plus explicit regime direction.
- H4/H1 directional disagreement is represented as a higher-timeframe trend / lower-timeframe correction rather than being treated as a trade signal.
- Neutral structure is not automatically called a range: `range` requires explicit upstream range evidence; otherwise the classifier returns `transition`.
- Added unit coverage for bullish/bearish alignment, both correction directions, neutral transition, explicit range evidence, and unknown precedence.
- Foundation only: no Strategy A Gate/Evidence, score, risk, RR, lifecycle, concurrency, entry, SL/TP, or historical backtest behavior changed.

### Phase 7 — Increment 079 Fix 2 source-contract literal matching

- Corrected the Increment 079 regression test again: it now verifies stable literal fragments (`risk blocked — ` and `reason.name`) without embedding Dart interpolation syntax inside the test string.
- Backtest runner and trading behavior are unchanged.


### Phase 7 — Increment 079 gate funnel diagnostics

- Added observation-level diagnostics for the frozen Strategy/Risk hard-gate funnel before changing any trading rule.
- Separately counts strategy warm-up skips, H4/H1 no-trade bias blocks, missing directional pullbacks, insufficient ATR history, observations reaching Risk analysis, Risk-eligible observations, and every `RiskEligibilityBlockReason`.
- Diagnostics are collected before lifecycle concurrency handling so `one signal plan at a time` does not hide where the underlying strategy/risk pipeline rejects opportunities.
- Diagnostics only: no Strategy, Gate/Evidence, scoring, risk, RR, lifecycle, waiting, concurrency, entry, SL/TP, or anti-look-ahead behavior changed.


### Phase 7 — Increment 078 unique qualified opportunity episodes

- Added diagnostics that de-duplicate consecutive qualified M5 observations into unique qualified opportunity episodes.
- A new episode starts only when qualification transitions from false/unavailable to true; consecutive qualified observations remain one episode, including observations seen while another plan is active.
- Reports unique qualified opportunity episodes and unique opportunities per observed broker wall-clock trading date alongside Increment 077 raw observation frequency.
- Diagnostics only: no Strategy, Gate/Evidence, score, risk, RR, lifecycle, waiting, concurrency, or anti-look-ahead behavior changed.


All notable changes to TradeForge V2 will be documented in this file.

## 2026-09-15

### Phase 7 — Increment 077 opportunity-frequency diagnostics

- Added opportunity-frequency diagnostics to the real XAUUSD full-lifecycle runner.
- Reports unique observed broker wall-clock trading dates, started qualified plans per observed trading date, all qualified candidate observations per observed trading date, and the share currently suppressed by the one-plan-at-a-time research policy.
- Keeps concurrency suppression visible instead of misclassifying it as a strategy-quality Gate.
- Added regression coverage for the new diagnostics.
- No strategy, Gate/Evidence, score, risk, RR, ATR, entry, lifecycle, waiting, concurrency, or anti-look-ahead behavior changed.
- Preserved the verified Increment 076 full-history baseline: 100,049 M5 observations, 203 started plans, 561 qualified candidates skipped while active, 87 resolved trades, 35 wins / 52 losses, 40.23% win rate, 2.8017 average planned RR, +0.4552R expectancy, and 1.7615 profit factor.

### Phase 7 — Increment 076 full available M5-history baseline

- Expanded the default real XAUUSD lifecycle replay limit from 50,000 to 100,049 M5 observations, matching the currently inspected available M5 dataset size.
- Kept the verified Increment 075 higher-timeframe replay cache enabled.
- Kept all strategy, Gate/Evidence, score, risk, minimum-RR, ATR, 12-candle waiting, entry-price, one-plan-at-a-time concurrency, lifecycle, ambiguity, anti-look-ahead, and broker wall-clock rules unchanged.
- Retained progress and throughput diagnostics so the full-history runtime can be measured.
- No strategy tuning or parameter optimization was performed.
- Preserved the verified 50,000-M5 comparison baseline: 53 resolved trades, 19 wins / 34 losses, 35.85% win rate, 2.7747 average planned RR, +0.2678R expectancy, and 1.4174 profit factor.

### Phase 7 — Increment 075 higher-timeframe replay cache

- Added a replay-local analysis cache for H4, H1, and M15 market-structure reconstruction.
- H4/H1 structure is recalculated only when a newly closed candle becomes visible for that timeframe.
- M15 structure plus Level/Liquidity analysis is recalculated only when a newly closed M15 candle becomes visible; the M5-dependent Strategy Setup Orchestrator still runs on every M5 observation.
- Added a regression test covering repeated M5 observations and cache refresh after the next M15 close.
- This is a performance-only increment: strategy rules, Gate/Evidence classification, score weights, risk parameters, entry policy, lifecycle behavior, and anti-look-ahead rules are unchanged.
- Preserved the verified Increment 074 baseline: 50,000 M5 observations, 53 resolved trades, 19 wins / 34 losses, 35.85% win rate, 2.7747 average planned RR, +0.2678R expectancy, and 1.4174 profit factor.

### Phase 7 — Increment 074 50,000-observation expansion

- Expanded the default real XAUUSD lifecycle replay window from 25,000 to 50,000 M5 observations.
- Kept all verified Increment 073 strategy, score, risk, minimum-RR, 12-candle waiting, entry, concurrency, lifecycle, and broker wall-clock policies unchanged.
- Retained 1,000-observation progress and throughput diagnostics.
- No strategy tuning, Gate/Evidence adjustment, or parameter optimization was performed.
- Preserved the verified 25,000-M5 baseline: 21 resolved trades, 8 wins / 13 losses, 38.10% win rate, 2.7784 average planned RR, +0.3607R expectancy, and 1.5826 profit factor.

### Phase 7 — Increment 073 25,000-observation expansion

- Expanded the default real XAUUSD lifecycle replay window from 10,000 to 25,000 M5 observations.
- Kept the verified Increment 072 strategy, score profile, risk settings, minimum RR, 12-candle waiting policy, entry-price policy, one-plan-at-a-time concurrency policy, lifecycle semantics, and broker wall-clock handling unchanged.
- Retained progress/timing diagnostics every 1,000 M5 observations so replay throughput can be compared directly with the 10,000-observation benchmark.
- No strategy tuning or parameter optimization was performed.
- Preserved the verified 10,000-M5 comparison baseline: 9 resolved triggered trades, 3 wins / 6 losses, 33.33% win rate, 2.9830 average planned RR, +0.1975R expectancy, and 1.2963 profit factor.

### Increment 072 duration-format analyzer correction

- Corrected the benchmark duration formatter so Dart does not parse the hour suffix as part of an interpolated identifier.
- Removed the remaining unnecessary-brace interpolation reported by the analyzer.
- Correction only; no 072 benchmark setting or frozen 071 trading/research rule changed.

### Increment 072 analyzer/test correction

- Escaped the progress-line interpolation tokens in the source-inspection test so the test checks the runner source literally instead of resolving test-scope variables.
- Removed the analyzer-reported unnecessary braces around the `hours` duration interpolation.
- Correction only; the 10,000-observation benchmark window and all frozen 071 strategy, risk, scoring, lifecycle, waiting, concurrency, and entry policies remain unchanged.

### Phase 7 — Increment 072 larger-window replay benchmark

- Expanded the default real XAUUSD lifecycle replay window from 2,000 to 10,000 M5 observations while keeping the verified Increment 071 strategy, risk, scoring, lifecycle, waiting, concurrency, and entry policies unchanged.
- Added progress output every 1,000 M5 observations so long historical runs no longer appear stalled.
- Added elapsed replay time and average observations-per-second diagnostics to establish a measured performance baseline before attempting any replay optimization.
- The runner still accepts an explicit `max-observations` argument, allowing 2,000/5,000/10,000 or other bounded comparisons without changing source code.
- No strategy tuning was performed. The 071 baseline remains the comparison point: 4 resolved trades, 1 win / 3 losses, 25.00% win rate, -0.1728R expectancy, and 0.7696 profit factor over its first 2,000 M5 observations.

### Increment 071 analyzer/test correction

- Corrected the source-inspection test so Dart does not interpolate the runner's private `_minimumRiskReward` identifier inside the test itself.
- Removed an unused `signal_engine` import and unnecessary non-null assertions reported by the analyzer.
- Correction only; no research parameter, Gate, Evidence weight, lifecycle, risk, data, or backtest policy changed.

### Phase 7 — Real XAUUSD full signal-lifecycle backtest

- Added the first real-data runner that extends verified XAUUSD Strategy/Risk/Signal Candidate replay through READY, pending invalidation/expiry, Entry Zone trigger, later-candle TP/SL monitoring, terminal historical records, and aggregate backtest metrics.
- The initial run remains bounded to 2,000 M5 observations by default while the real-data lifecycle integration is validated before full-history performance work.
- Added an explicit research waiting limit of 12 closed M5 candles. This is an uncalibrated research hypothesis, not a production default.
- Added an explicit baseline concurrency policy: only one signal plan is tracked at a time; new qualified candidates are ignored while a plan is active. The count of skipped qualified candidates is printed so this assumption remains visible and measurable.
- A candle that terminates an active signal plan is not reused to start another signal plan on that same OHLC observation.
- Preserved the frozen conservative trigger-candle rule: TP/SL monitoring starts only on later M5 candles after Entry Zone trigger.
- Terminal INVALIDATED/EXPIRED records remain excluded from triggered win/loss metrics; ambiguous same-candle TP/SL remains non-terminal upstream.
- The runner prints terminal records, invalidated/expired counts, resolved triggered trades, wins, losses, win rate, average planned RR, expectancy R, and profit factor.
- Existing research parameters remain explicit and uncalibrated; no Gate, Evidence weight, strategy rule, timezone assumption, spread/slippage/fee model, or user-position state was changed.

### Phase 7 — Real XAUUSD Strategy/Risk/Signal replay smoke runner

- Added a bounded real-data replay command that loads the verified XAUUSD M5/M15/H1/H4 MT5 history and sends it through the frozen multi-timeframe synchronization, Strategy Engine replay, Risk Engine replay, and Signal Candidate replay.
- The command reports real candidate construction/qualification counts and BUY/SELL/NO TRADE direction counts without pretending that TP/SL lifecycle performance has already been measured.
- The first smoke-run research configuration is explicit and printed in the output: equality tolerance `0.10`, M15 level zone half-width `0.50`, level merge max-gap `0.20`, `baseline-research@v1`, M15 ATR(14), ATR stop multiplier `0.50`, minimum RR `2.0`, and matched M15 pullback-level midpoint as the research entry price.
- These values are uncalibrated research hypotheses, not production defaults or claims of optimal XAUUSD parameters.
- The real replay is intentionally bounded to 250 M5 observations by default, with an explicit optional observation limit, so the existing full-history analyzers can be validated on real data before performance optimization/full-run work.
- No Gate, Evidence weight, strategy rule, lifecycle rule, timezone assumption, or execution behavior was changed.

### Increment 069 analyzer correction

- Corrected the XAUUSD inspection CLI to use the frozen MT5 adapter API exactly: `Mt5HistorySeries`, named `content`, and `series.candles`.
- This is a compile/analyzer correction only; no data policy, strategy rule, Gate, evidence weight, or backtest assumption changed.

### Phase 7 — Real XAUUSD MT5 CSV inspection runner

- Added a CLI entry point for loading the existing XAUUSD M5/M15/H1/H4 2024–2026 MT5 CSV history through the frozen `Mt5HistoryAdapter`.
- The command validates that all four required history files exist and contain candles, then prints candle counts and first/last timestamps per timeframe.
- Broker wall-clock timestamps remain preserved; the runner explicitly does not guess UTC or another timezone.
- This increment is deliberately an input-validation bridge only: it does not yet claim strategy metrics from real data and introduces no research parameter defaults, Gate changes, or trading assumptions.
- Once this runner is verified against the user's real V1 dataset, the next increment can wire the explicit research configuration into the full historical strategy/risk/signal/report pipeline.

### Phase 7 — Backtest run report integration

- Added immutable `BacktestRunReport` as the integration boundary between completed historical signal-plan records and aggregate metrics.
- Added `BacktestRunReportBuilder`, which freezes the supplied record collection and calculates one internally consistent metrics snapshot.
- Empty runs remain valid and do not invent rates, expectancy, or profit factor.
- Report construction adds no replay rule, fill assumption, Gate, score threshold, spread, slippage, fee, or position-management behavior.
- This prepares the backtesting package for the next increment: loading the existing XAUUSD MT5 CSV history and producing the first real historical research run.

### Phase 7 — Backtest metrics foundation

- Added deterministic aggregate metrics over frozen historical signal records.
- Added resolved triggered trade count, wins, losses, win rate, average planned RR, expectancy in R, and profit factor.
- `INVALIDATED` and `EXPIRED` remain signal-plan outcomes and are excluded from the win/loss denominator.
- Expectancy uses the current research model: TP contributes its explicit planned RR and SL contributes `-1R`.
- Profit factor is left unavailable when there are no losses instead of inventing infinity or a fallback value.
- No fees, spread, slippage, position sizing, score threshold, Gate, or new strategy rule was introduced.

### Phase 7 — Historical signal result record foundation

- Added an immutable `HistoricalSignalRecord` for research output after a historical signal plan reaches an unambiguous terminal lifecycle state.
- Records preserve direction, READY/TRIGGERED/terminal observation indexes, waiting-candle count, explicit Entry/SL/TP/RR values, setup score, and terminal outcome.
- Pre-trigger `INVALIDATED` and `EXPIRED` outcomes remain separate from triggered TP/SL results and therefore are not silently counted as trading losses.
- READY and still-TRIGGERED states do not emit terminal records.
- Ambiguous same-candle SL/TP remains unresolved upstream and therefore cannot be emitted as a win/loss record.
- Entry, SL, TP, and RR remain explicit research inputs; this result layer adds no fill policy, gate, score threshold, or trading assumption.

### Increment 065 test fixture correction

- Corrected the historical lifecycle test candle helper so its synthetic `open` price always remains inside the supplied `[low, high]` range.
- This is a test-fixture-only correction; no historical lifecycle, signal, risk, strategy, or trading rule changed.

### Phase 7 — Full historical signal lifecycle state integration

- Added one immutable historical state machine that composes the already-frozen READY/waiting, pending validity, Entry Zone trigger, and triggered TP/SL monitoring adapters.
- Qualified candidates can now progress across later closed M5 observations through `READY -> TRIGGERED -> TP/SL`, or terminate before trigger as `INVALIDATED` / `EXPIRED`.
- Terminal historical states remain terminal and are not reactivated by later candles.
- The Entry Zone trigger candle establishes `TRIGGERED` only; TP/SL monitoring begins on later closed M5 candles so OHLC backtesting does not invent intrabar ordering between Entry Zone contact and SL/TP.
- Post-trigger candles that touch both SL and TP preserve the frozen ambiguous non-terminal outcome rather than being counted as a win or loss.
- This integration adds no new trading gate, evidence weight, ATR parameter, RR threshold, or execution/position assumption.

### Phase 7 — Historical triggered TP / SL monitoring foundation

- Added a historical adapter over the frozen Phase 6 `TriggeredSignalMonitor` for later closed M5 candles after a signal plan is TRIGGERED.
- Historical observations report `monitoring`, `takeProfitReached`, or `stopLossReached` using the frozen BUY/SELL SL/TP touch rules.
- Exact SL and TP boundary contact counts as a touch.
- A candle touching both SL and TP remains non-terminal with `ambiguousSameCandleOutcome`; OHLC replay does not invent intrabar ordering or classify the candle as a win/loss.
- The adapter records the historical observation index and does not infer or manage the user's real trading position.
- Full stateful lifecycle replay across READY -> TRIGGERED -> terminal outcome remains a separate integration increment.

### Phase 7 — Historical Entry Zone trigger replay

- Added historical Entry Zone trigger evaluation for READY signals using the frozen `EntryZoneTriggerDetector`.
- Each newly closed M5 candle advances the waiting count once, then pending structural invalidation / expiry is evaluated before Entry Zone contact.
- INVALIDATED and EXPIRED signals cannot become TRIGGERED on the same candle; their trigger analysis is intentionally omitted.
- Entry Zone contact uses the frozen inclusive range-intersection rule, so touching either zone boundary counts as contact.
- A valid signal that misses the Entry Zone remains waiting; a valid signal that reaches the Entry Zone becomes historically TRIGGERED.
- This increment does not yet evaluate post-trigger TP / SL outcomes.

### Phase 7 — Historical pending INVALIDATED / EXPIRED replay

- Added historical pending-signal validity evaluation for each later closed M5 candle while a signal remains READY.
- Reuses the frozen `PendingSignalValidityEvaluator`; no duplicate invalidation or expiry rules were invented in backtesting.
- BUY invalidates only when candle close is below the structural boundary; SELL invalidates only when close is above it. Exact boundary contact remains valid.
- The waiting count advances once for the newly observed closed M5 candle before validity evaluation.
- `maximumWaitingCandles` remains an explicit research input with no hidden default.
- Frozen invalidation-before-expiry priority is preserved when both conditions become true on the same candle.
- Entry Zone triggering is intentionally excluded and remains the next lifecycle increment.

### Phase 7 — Historical READY / waiting state foundation

- Added immutable historical READY state for one qualified `SignalCandidate`.
- READY creation validates the frozen adjacent lifecycle path `SCANNING -> WATCHING -> SETUP_FORMING -> READY`; it does not skip lifecycle states.
- Blocked candidates cannot create historical READY state.
- Each later closed M5 observation can advance the explicit waiting-candle count exactly once while preserving the original READY observation index and candidate.
- Waiting returns a new immutable state and does not mutate prior historical observations.
- INVALIDATED / EXPIRED evaluation and Entry Zone triggering are intentionally not included in this increment.
- Corrected the READY-state test fixture to the frozen `SetupEvidenceSnapshot` and `SetupScoreResult` constructor APIs; production lifecycle logic is unchanged.

### Phase 7 — Signal Candidate historical replay integration

- Connected verified historical Strategy + Risk replay output to the frozen Phase 6 `SignalCandidateBuilder`.
- Historical candidate construction reuses the exact strategy bias, evidence snapshot, research score, and `RiskPlanAnalysis` from the same anti-look-ahead observation.
- Upstream skipped/blocked observations do not fabricate a signal candidate.
- No score threshold was introduced; the research score remains evidence rather than a hidden signal gate.
- This increment intentionally stops at candidate construction. Stateful READY waiting, INVALIDATED/EXPIRED handling, Entry Zone triggering, and post-trigger TP/SL monitoring remain separate follow-up increments.

### Phase 7 — Risk Engine historical replay integration

- Connected historical Strategy Setup results to the frozen Phase 5 `RiskPlanOrchestrator`.
- Strategy replay now retains the exact historical `LevelLiquidityAnalysis` used by Strategy Engine so Risk Engine consumes the same key-level facts without recomputation drift.
- Added explicit research inputs for ATR timeframe, ATR period, ATR stop multiplier, minimum RR policy, and historical entry-price resolver; no XAUUSD defaults were introduced.
- Risk planning stops early for strategy-skipped and strategy-blocked observations.
- ATR is calculated only from candles visible at the historical M5 observation time and requires `period + 1` closed candles.
- Historical risk output retains ATR, explicit entry price, and the complete frozen `RiskPlanAnalysis` including Entry Zone, structural/protective SL, TP candidate, RR, minimum-RR gate, and eligibility.
- No Signal Engine replay, fill simulation, TP/SL outcome resolution, metrics, or parameter calibration was added yet.

### Phase 7 — Strategy Engine historical replay integration

- Connected the Phase 7 historical replay directly to the frozen `MarketStructureAnalyzer`, `LevelLiquidityAnalyzer`, and `StrategySetupOrchestrator`.
- At each M5 close, H4/H1/M15 structure is rebuilt only from candles visible at that historical instant.
- M15 key levels and liquidity evidence are rebuilt only from confirmed historical M15 swings.
- Added explicit research inputs for equality tolerance, zone half-width, level merge gap, and score profile; no hidden XAUUSD defaults were introduced.
- Historical steps before the first closed M15 candle are explicitly skipped.
- D1 context and level-strength evidence remain unavailable rather than being fabricated.
- Added direct `strategy_engine` and `technical_analysis` dependencies to the backtesting package.
- No Risk Engine, Signal Engine, TP/SL outcome replay, metrics, or parameter calibration was added yet.

### Phase 7 — Historical strategy replay foundation

- Added generic `HistoricalStrategyReplay<T>` driven by the synchronized M5 historical feed.
- Executes exactly one supplied strategy evaluation for each historical M5 close and retains the exact observation/result pair.
- Replay is lazy and chronological, so future historical steps are not evaluated early.
- The evaluator receives only the anti-look-ahead multi-timeframe observation already permitted at that historical instant.
- Kept strategy-specific orchestration outside this foundation so Phase 7 does not duplicate or distort the frozen Strategy Engine API.
- No performance metrics, signal lifecycle mutation, parameter calibration, or trade outcome accounting was added yet.

### Phase 7 — Multi-timeframe backtest synchronization

- Added an M5-driven `MultiTimeframeBacktestFeed` for M5, M15, H1, and H4 historical research.
- Every observation occurs at the current M5 candle close; higher-timeframe candles are exposed only after their own `closeTime` is reached.
- Exact close boundaries are inclusive, while still-open H1/H4/M15 candles remain hidden.
- Each timeframe history is immutable and contains no future candles.
- Reuses the existing strict chronology/overlap validation from `BacktestCandleFeed`.
- No D1 aggregation, strategy replay, signal generation, performance metrics, or parameter calibration was added in this increment.

### Phase 7 — MT5 adapter analyzer fix

- Wrapped the MT5 angle-bracket column names in backticks inside the API documentation comment.
- Removes all `unintended_html_in_doc_comment` analyzer diagnostics from Increment 055.
- Production parsing behavior and tests are unchanged.

### Phase 7 — MT5 history adapter

- Added `Mt5HistoryAdapter` for the exact tab-separated MT5 history format already available from TradeForge V1.
- Added explicit M5, M15, H1, and H4 timeframe metadata; candle close time is derived from the selected timeframe.
- Parsed `<TICKVOL>` is retained as `Candle.volume` because the existing V1 exports carry activity there while `<VOL>` is zero.
- MT5 broker wall-clock timestamps are preserved without guessing a timezone. Broker/session timezone normalization is intentionally deferred until source metadata is known.
- Unsupported headers, malformed rows, invalid numeric/date values, and out-of-order candles are rejected.
- Added integration coverage proving parsed MT5 candles can enter the Phase 7 anti-look-ahead feed.
- Existing V1 historical CSV files are reused; this increment does not duplicate or bundle the multi-megabyte datasets.
- No multi-timeframe synchronization, D1 aggregation, strategy replay, performance metrics, or parameter calibration was added yet.

### Phase 7 — Backtest data foundation

- Created standalone `research/backtesting` Dart package for deterministic historical research.
- Added `BacktestCandleFeed` as the first anti-look-ahead boundary.
- Historical candles must be supplied in strictly increasing `openTime` order; duplicate and out-of-order data is rejected rather than silently sorted.
- Overlapping candle intervals are rejected.
- Each observation exposes only the current candle and immutable history available up to that point; future candles are never exposed.
- Empty datasets are valid.
- No strategy execution, multi-timeframe synchronization, performance metrics, XAUUSD dataset import, or parameter calibration was added yet.

### Phase 6 — Signal Engine integration

- Added `SignalEngineOrchestrator` as the unified Phase 6 application flow over the frozen Candidate, pending-validity, Entry Zone trigger, and triggered-monitoring components.
- Pending evaluation order is explicit: Candidate hard requirements -> structural validity/expiry -> Entry Zone trigger.
- Blocked candidates do not proceed to validity or trigger evaluation.
- Invalidated or expired signals cannot become triggered on the same evaluation.
- Qualified valid signals remain waiting until Entry Zone market contact, then become triggered.
- Triggered signal monitoring reuses the existing TP/SL observer and still does not model the user's real position.
- Added integration coverage across waiting, triggering, invalidation precedence, expiry precedence, and post-trigger TP monitoring.
- No score threshold, user-position state, notification transport, AI reasoning, or order execution was added.

### Phase 6 — Pending signal invalidation and expiry foundation

- Added deterministic validity monitoring for signals that have not triggered yet.
- BUY pending signals invalidate when a closed candle closes below the structural invalidation boundary; exact boundary close remains valid.
- SELL pending signals invalidate when a closed candle closes above the structural invalidation boundary; exact boundary close remains valid.
- Added configurable candle-count expiry with no hidden default waiting period.
- Structural invalidation takes precedence when invalidation and expiry occur on the same candle.
- Invalidated and expired signals can no longer trigger.
- No user-position management, notification transport, AI reasoning, or execution logic was added.

### Phase 6 — Triggered signal monitoring foundation

- Added deterministic post-trigger monitoring for published BUY/SELL signal plans without introducing user-position management.
- Closed candles are observed against the signal's planned SL and TP.
- BUY and SELL signals can remain monitoring, reach TP, or reach SL.
- Exact SL/TP boundary contact counts as reached.
- When one OHLC candle touches both SL and TP, the engine does not guess intrabar order; it reports an explicit ambiguous monitoring result.
- TradeForge still does not track whether the user entered a real position.
- No ACTIVE/user-position state, partial TP, trailing stop, break-even management, notification transport, AI reasoning, or execution logic was added.

### Increment 050 dependency fix

- Added `technical_analysis` as an explicit `signal-engine` dependency because the Increment 050 test directly constructs frozen technical-analysis domain types.
- Removes the `depend_on_referenced_packages` analyzer issue without relying on a transitive dependency.
- Entry Zone trigger production logic is unchanged.

### Phase 6 — Entry Zone trigger condition foundation

- Added deterministic `EntryZoneTriggerDetector` for READY-signal market contact.
- A directional signal is considered trigger-ready when a closed candle's price range intersects the planned Entry Zone; exact boundary contact is included.
- Signals remain waiting while the candle range stays outside the Entry Zone.
- `NO TRADE` and unavailable Entry Zones are explicitly not applicable.
- Trigger detection is observation only: it does not mutate lifecycle state, choose a fill price, execute an order, or notify the user.
- No spread/slippage model, intrabar sequencing, ACTIVE state, TP/SL outcome handling, or execution logic was added.

### Phase 6 — READY to TRIGGERED lifecycle transition

- Extended the deterministic signal lifecycle with the `TRIGGERED` state.
- Added the valid adjacent transition `READY -> TRIGGERED`.
- A signal cannot skip `READY` and jump directly from `SETUP_FORMING` to `TRIGGERED`.
- `TRIGGERED` cannot move backward or self-transition under the baseline lifecycle rules.
- This increment defines lifecycle progression only; market-price trigger conditions, `ACTIVE`, outcomes, notifications, AI reasoning, and execution remain out of scope.

### Phase 6 — Signal lifecycle pre-trigger foundation

- Added the first deterministic signal lifecycle states: `SCANNING -> WATCHING -> SETUP_FORMING -> READY`.
- Added explicit transition validation and typed rejection reasons for same-state, backward, and skipped-state transitions.
- Only adjacent forward progression is allowed in this baseline, preventing a signal from silently jumping from scanning directly to ready.
- This increment intentionally stops at `READY`; `TRIGGERED`, `ACTIVE`, `TP/SL`, `MISSED`, `INVALIDATED`, and `EXPIRED` are not introduced yet.
- No score threshold, notification, AI reasoning, or execution behavior was added.

### Increment 047 test compatibility fix

- Corrected the `RiskReward` fixture to match the frozen Phase 5 constructor.
- Added the required explicit `entryPrice`, `stopPrice`, `targetPrice`, and `bias` fields.
- Production Signal Candidate logic is unchanged.

### Phase 6 — Signal Candidate foundation

- Created the standalone `packages/signal-engine` package.
- Added immutable `SignalCandidate` as the first Phase 6 bridge between the frozen Strategy Engine and Risk Engine outputs.
- A candidate retains the complete `SetupEvidenceSnapshot`, research `SetupScoreResult`, and `RiskPlanAnalysis`.
- Strategy eligibility and Risk eligibility remain hard requirements; the research score is explicitly not promoted to a new Gate.
- BUY and SELL can become qualified candidates only when both upstream hard-requirement layers pass.
- NO TRADE remains a first-class blocked direction and cannot become a qualified candidate.
- Added explicit block reasons for strategy, risk, and missing directional bias.
- No score threshold, READY/TRIGGERED lifecycle, notification, AI reasoning, or order execution was introduced.

### Increment 046 test compatibility fix

- Corrected the eligible `SetupEvidenceSnapshot` fixture to provide the frozen required `blockReason` parameter explicitly as `null`.
- Production `RiskPlanAnalysis` and `RiskPlanOrchestrator` logic are unchanged.

### Phase 5 — Unified Risk Plan integration

- Added `RiskPlanAnalysis` as the unified Phase 5 output retaining Entry Zone, structural invalidation, Protective SL, target, RR, minimum-RR gate, and final risk eligibility.
- Added `RiskPlanOrchestrator` to connect the previously tested Phase 5 components without introducing new trading rules.
- ATR value, ATR multiplier, minimum RR, entry price, and candidate Key Levels remain explicit caller inputs; no hidden XAUUSD calibration or execution-price assumption was added.
- The orchestrator does not silently choose Entry Zone midpoint/edge as the trade entry.
- Missing targets remain unavailable instead of generating synthetic fixed-RR take-profit prices.
- Added end-to-end BUY and SELL risk-plan tests plus below-minimum-RR, blocked-setup, and missing-target paths.
- This increment is the Phase 5 integration candidate; Phase 5 is not frozen until package analysis/tests pass.
- No position sizing, account-risk percentage, TP2/TP3, Signal Engine lifecycle, AI reasoning, or order execution was introduced.

### Increment 045 test compatibility fix

- Corrected `risk_eligibility_test.dart` to use the frozen Increment 039 `ProtectiveStop` API.
- Replaced the nonexistent `structuralStopUnavailable` enum value with `noStructuralStop`.
- Added the required `bufferDistance` argument and removed the nonexistent `sourceLevel` argument from the `ProtectiveStop` fixture.
- Production `RiskEligibility` logic is unchanged.

### Phase 5 — Unified risk eligibility integration

- Added `RiskEligibility`, `RiskEligibilityStatus`, `RiskEligibilityBlockReason`, and `RiskEligibilityEvaluator`.
- Unified the existing Phase 5 outputs into one deterministic risk-eligibility decision for downstream Signal Engine work.
- Risk eligibility now checks, in order: Entry Zone availability, Protective SL availability, structure-derived target availability, valid RR geometry, and the configurable minimum-RR hard gate.
- Blocked results expose a specific reason instead of collapsing every failure into generic NO TRADE.
- Below-minimum setups preserve the measured RR and configured threshold for later research, explanations, and backtesting.
- This layer does not generate BUY/SELL signals and does not change Strategy Engine eligibility.
- No position sizing, account-risk percentage, TP2/TP3, final signal lifecycle, AI reasoning, or order execution was introduced.

### Phase 5 — Configurable minimum RR risk gate foundation

- Added `MinimumRiskRewardPolicy` as an explicit, validated research parameter with no production default.
- Added `MinimumRiskRewardGate` and `MinimumRiskRewardGateResult` to keep RR measurement separate from trade eligibility.
- Valid RR passes when `actualRatio >= minimumRatio`; equality is intentionally accepted.
- Invalid RR geometry and NO TRADE measurements are blocked before threshold comparison.
- Below-threshold RR is reported explicitly as `belowMinimumRatio`.
- The same setup can be evaluated against different minimum-RR policies, enabling later Phase 7 backtests across thresholds such as 1.5, 1.8, 2.0, or 2.5 without changing calculator logic.
- No XAUUSD minimum RR has been selected, and no win probability, position sizing, final signal, or order execution was introduced.

### Phase 5 — Risk/reward calculator foundation

- Added `RiskReward`, `RiskRewardAnalysis`, and `RiskRewardCalculator`.
- BUY risk is `entry - stop` and reward is `target - entry`.
- SELL risk is `stop - entry` and reward is `entry - target`.
- RR is calculated deterministically as `rewardDistance / riskDistance`.
- Invalid stop/target geometry is reported explicitly for BUY and SELL; NO TRADE cannot produce a valid RR measurement.
- Entry, stop, and target prices must be finite.
- The calculator accepts an explicit entry price and deliberately does not choose midpoint/edge/user-fill policy.
- Added tests for BUY/SELL RR, precision, invalid geometry, NO TRADE, and non-finite prices.
- No minimum-RR Gate, default threshold, win-probability interpretation, position sizing, or order execution was introduced.

### Phase 5 — Structure-derived TP target foundation

- Added `TargetCandidate`, `TargetCandidateAnalysis`, and `TargetCandidatePlanner`.
- BUY setups select the nearest active resistance strictly above an explicit reference price.
- SELL setups select the nearest active support strictly below an explicit reference price.
- The first target uses the near edge of the opposing zone: resistance lower bound for BUY and support upper bound for SELL.
- Same-direction levels, levels behind price, and non-active levels are ignored.
- Exact target-price ties prefer the newer level by `createdAtCandleIndex`.
- Missing forward opposing structure and NO TRADE states remain explicitly unavailable.
- No fixed-RR target, TP2/TP3, liquidity-pool target, RR threshold, position sizing, or order execution was introduced.

### Phase 5 — ATR stop-buffer integration

- Added `AtrStopBufferMultiplier` and `AtrStopBufferPolicy` to `risk-engine`.
- Risk Engine can now convert an externally computed ATR value into `StopBuffer` using the deterministic formula `ATR × multiplier`.
- ATR calculation remains owned by `technical-analysis`; Risk Engine consumes the resulting volatility value instead of duplicating indicator logic.
- Both ATR and multiplier must be finite and greater than zero.
- Added integration tests proving ATR-derived buffers feed the existing BUY/SELL `ProtectiveStopPlanner` and place stops outside structural invalidation boundaries.
- No default ATR timeframe, ATR period, multiplier, XAUUSD calibration, TP, RR, position sizing, or order execution was introduced.

### Phase 5 support — ATR foundation in technical analysis

- Added deterministic True Range and Average True Range calculations to `technical-analysis`.
- True Range accounts for candle range and gaps versus the previous close.
- Baseline ATR uses an explicit arithmetic mean over the latest `period` True Range values.
- ATR requires `period + 1` strictly chronological candles so every averaged True Range has a real previous close.
- No default ATR period, timeframe, Wilder/RMA smoothing, stop multiplier, XAUUSD calibration, or Risk Engine integration was introduced.
- Added tests for candle range, upside/downside gaps, latest-window averaging, invalid period, insufficient history, and chronological ordering.

### Phase 5 — Protective stop buffer foundation

- Added `StopBuffer`, `ProtectiveStop`, `ProtectiveStopAnalysis`, and `ProtectiveStopPlanner`.
- BUY protective stops are placed below the structural invalidation boundary by an explicit positive buffer.
- SELL protective stops are placed above the structural invalidation boundary by an explicit positive buffer.
- Buffer magnitude is deliberately supplied as data rather than hard-coded into the planner, allowing a later ATR/volatility model to determine it independently.
- Stop buffers must be finite and greater than zero; missing structural stops cannot produce protective stops.
- Added tests for BUY/SELL placement, outside-structure semantics, invalid buffer values, and missing structural stop.
- No fixed-pip default, ATR calculation, spread adjustment, TP, RR, position sizing, or order execution was introduced.

### Phase 5 — Structural stop / invalidation foundation

- Added `StructuralStop`, `StructuralStopAnalysis`, and `StructuralStopPlanner`.
- BUY setups use the matched support level's lower bound as the pure structural invalidation boundary.
- SELL setups use the matched resistance level's upper bound as the pure structural invalidation boundary.
- Direction/level mismatches are rejected explicitly; NO TRADE and missing Entry Zone states cannot produce a structural stop.
- Boundary touch alone is not classified as structural invalidation; price must cross beyond the boundary.
- The structural boundary is deliberately not yet a broker-ready stop order. A later increment will add an explicit protective buffer outside structure.
- Added tests for BUY, SELL, boundary semantics, missing Entry Zone, NO TRADE, and directional-level mismatch.
- No fixed-pip stop, ATR buffer, spread adjustment, TP, RR, position sizing, or order execution was introduced.

### Phase 5 — Risk Engine package and Entry Zone foundation

- Started the standalone `risk-engine` package so risk planning remains separate from strategy eligibility and evidence scoring.
- Added `EntryZone`, `EntryZoneAnalysis`, and `EntryZonePlanner`.
- An Entry Zone is available only when Phase 4 reports an eligible setup and the pullback analysis has a matched directional key level.
- The baseline Entry Zone reuses the validated pullback level bounds instead of inventing a fake-precision single entry price.
- Blocked setups and eligible setups without a matched pullback level remain explicitly unavailable.
- Added tests for BUY/support, SELL/resistance, blocked setup, missing matched level, inclusive zone boundaries, and midpoint derivation.
- No spread adjustment, ATR offset, SL, TP, RR, position sizing, order execution, or final executable signal was introduced.

### Increment 036 verification fixture correction

- Corrected the bullish Phase 4 integration-test score expectation from 65 to 80.
- The fixture legitimately contains five positive soft-evidence contributions: rejection 15, M15 structure 20, M5 confirmation 15, key-level quality 15, and aligned D1 context 15.
- No production strategy, Gate, Evidence, scoring policy, or orchestration logic changed.

### Phase 4 — Strategy setup orchestration and integration

- Added `StrategySetupOrchestrator` as the Phase 4 integration boundary for the Trend + Pullback strategy.
- The orchestrator now coordinates H4/H1 bias, M15 directional pullback, pullback rejection, liquidity evidence, M15 structure evidence, M5 confirmation evidence, key-level quality, D1 context, setup eligibility, immutable evidence snapshot, and research scoring.
- Added `StrategySetupAnalysis` so downstream phases receive one transparent result while all intermediate facts remain inspectable.
- Optional D1, liquidity, and level-strength inputs remain explicitly unavailable/absent when missing; the orchestrator does not guess market facts.
- Existing Gates remain unchanged: directional H4/H1 alignment and valid directional pullback.
- Research score remains separate from eligibility and cannot override a blocked setup.
- Added integration coverage for a complete bullish setup, higher-timeframe conflict, missing pullback, and unavailable optional context.
- No Entry, SL, TP, RR, order execution, or final executable BUY/SELL signal was introduced.
- This increment is intended to close Phase 4 after verification.

### Phase 4 — Versioned research score profile

- Added `SetupScoreProfile` to give scoring configurations explicit IDs, versions, descriptions, and validated policies.
- Added `baseline-research@v1` as a research-only starting hypothesis for future A/B backtests.
- Kept current hard requirements (`directionalBias` and `pullbackAtDirectionalLevel`) at zero score weight to avoid double-counting Gate facts.
- The initial soft-evidence research budget is transparent and totals 100 points: M15 structure 20; rejection 15; M5 confirmation 15; key-level quality 15; D1 context 15; directional level sweep 10; directional liquidity-pool sweep 10.
- These values are not production-calibrated, do not represent win probability, and are expected to change through backtesting.
- No score thresholds, grades, Entry, SL, TP, RR, or final BUY/SELL signal were introduced.

### Phase 4 — Configurable setup-score foundation

- Added a deterministic `SetupScorer` that consumes the immutable setup evidence snapshot.
- Added `SetupScorePolicy`, keeping evidence weights as replaceable configuration rather than embedding weights in strategy branching logic.
- Added transparent per-evidence score contributions plus earned and available points for later research and backtesting.
- Missing weights default to zero; configured weights must be finite and non-negative.
- Scoring is deliberately independent from setup eligibility: a score cannot override a Gate or make a blocked setup eligible.
- No default production weights, score thresholds, grades, win-probability claims, Entry, SL, TP, RR, or final BUY/SELL signal were introduced.
- This foundation allows later backtesting to tune weights or reclassify Evidence and Gates without redesigning the scoring engine.

### Phase 4 — Structured setup evidence snapshot

- Added an immutable `SetupEvidenceSnapshot` as the unified data boundary for strategy evidence.
- Snapshot captures setup eligibility, block reason, all boolean evidence states, detailed D1 context alignment, and detailed key-level quality.
- Preserved false/missing evidence rather than storing only positive signals, which is important for later backtest comparisons.
- Snapshot defensively copies its evidence collection and exposes an immutable evidence-presence map.
- No score, arbitrary weights, grade, win probability, Entry, SL, TP, RR, or final BUY/SELL signal was introduced.
- This keeps Evidence-to-Gate reclassification possible later without redesigning the evidence collectors.

### Phase 4 — D1 market-context evidence integration

- Added explicit D1 context alignment states: unavailable, aligned, neutral, and opposed.
- BUY + bullish D1 and SELL + bearish D1 add positive directional context evidence.
- Opposed, neutral, and unknown D1 context remain observable without blocking an otherwise eligible setup.
- D1 therefore remains context/evidence rather than a hard direction gate in the current baseline.
- Integrated D1 context into SetupEvaluation without changing the existing hard requirements.
- Preserved the alignment category separately so later backtesting can promote D1 alignment to a Gate, penalize opposed context, or leave it as Evidence without redesigning the strategy layer.
- Numeric scoring, Entry, SL, TP, RR, and final signal generation remain outside this increment.

### Phase 4 — Key-level quality evidence integration

- Added a dedicated key-level quality evidence model backed by the Phase 3 level-strength categories.
- Preserved `weak`, `established`, and `wellTested` quality information without assigning arbitrary numeric weights.
- Established and well-tested levels currently count as positive quality evidence; weak or unavailable strength simply means the positive evidence is absent.
- Key-level quality remains soft evidence and does not become a new setup gate.
- Integrated key-level quality into SetupEvaluation without changing the existing hard requirements.
- The detailed quality category remains available separately so later backtesting can assign different weights or promote/demote the condition between Evidence and Gate if data supports it.
- Numeric scoring, Entry, SL, TP, RR, and final signal generation remain outside this increment.

### Phase 4 — M5 entry-confirmation evidence foundation

- Added a dedicated M5 directional entry-confirmation evidence evaluator.
- BUY setups receive positive M5 evidence from a closed bullish M5 candle; SELL setups receive positive evidence from a closed bearish M5 candle.
- Doji and opposite-direction M5 candles do not add positive evidence.
- M5 confirmation is explicitly soft evidence and does not become a new hard gate.
- Integrated directional M5 confirmation into SetupEvaluation without changing setup eligibility requirements.
- This baseline intentionally does not treat a single M5 candle as a final entry trigger; more precise M5 structure/rejection behavior remains available for later backtest-driven refinement.
- Numeric scoring, Entry, SL, TP, RR, and final BUY/SELL signal generation remain outside this increment.

### Phase 4 — M15 market structure evidence integration

- Added a dedicated M15 market-structure evidence evaluator.
- BUY setups receive positive structure evidence when M15 structure is bullish.
- SELL setups receive positive structure evidence when M15 structure is bearish.
- Neutral, unknown, and opposite-direction M15 structures do not add positive evidence.
- M15 structure remains soft evidence: missing or opposite structure does not create a new hard gate or block an otherwise eligible setup.
- Integrated directional M15 structure into SetupEvaluation without changing the existing hard requirements.
- Numeric scoring, weights, M5 trigger logic, Entry, SL, TP, RR, and final BUY/SELL signal generation remain outside this increment.

### Phase 4 — Increment 028 test fixture compatibility fix

- Corrected strategy-engine liquidity tests to match the already-frozen Phase 3 domain constructors.
- Removed invalid `const` usage from `KeyLevel` fixtures because `KeyLevel` performs runtime validation.
- Updated `LiquidityPool` fixtures to use the required `swingCandleIndexes` field instead of the obsolete/nonexistent `swings` argument.
- No production strategy or liquidity behavior changed in this fix.

### Phase 4 — Liquidity evidence integration

- Connected the already-tested Phase 3 liquidity analysis output to the Phase 4 strategy evidence layer.
- BUY setups recognize sweeps below active support and raids below equal-low liquidity pools as directional liquidity evidence.
- SELL setups recognize sweeps above active resistance and raids above equal-high liquidity pools as directional liquidity evidence.
- Opposite-direction liquidity events are ignored for the current bias.
- Liquidity evidence is explicitly soft evidence: its absence does not block an otherwise eligible setup.
- Extended SetupEvaluation with directional level-sweep and pool-sweep evidence while preserving the existing minimal hard requirements.
- Kept numeric weights, grades, final signals, Entry, SL, TP and RR out of this increment so evidence can be backtest-calibrated later.

### Phase 4 — Setup evidence evaluation foundation

- Added the first strategy-level setup evaluator that explicitly separates hard requirements from quality evidence.
- Kept the hard requirements intentionally small: a directional BUY/SELL bias and a valid directional pullback.
- Rejection confirmation is now modeled as soft setup evidence rather than another mandatory gate.
- A setup may therefore remain eligible while rejection confirmation is absent; later scoring can reduce its quality instead of forcing NO TRADE.
- Added machine-readable setup eligibility, block reasons, and evidence types.
- Added an immutable evidence collection and helpers for querying present evidence.
- This increment deliberately does not assign numeric weights, grades, Entry, SL, TP, RR, or final BUY/SELL signals; those remain separate calibrated layers.

### Phase 4 — Pullback rejection confirmation foundation

- Added the first deterministic confirmation rule after a directional pullback enters its matched key-level zone.
- BUY confirmation requires a bullish candle that closes strictly back above the matched support zone.
- SELL confirmation requires a bearish candle that closes strictly back below the matched resistance zone.
- Closing exactly on the zone boundary is deliberately insufficient for confirmation.
- Confirmation remains in a waiting state while price is still inside the zone, while candle direction is wrong, or while no valid pullback is active.
- NO TRADE bias makes confirmation explicitly not applicable.
- Added machine-readable confirmation states and reasons for later setup/lifecycle logic.
- This is rejection evidence only; it does not yet produce a final trade trigger, Entry, SL, TP, RR, setup score, or AI confidence.

### Phase 4 — Directional pullback detection

- Added deterministic pullback detection for the Trend + Pullback strategy.
- BUY bias only recognizes interaction with an ACTIVE support zone; SELL bias only recognizes interaction with an ACTIVE resistance zone.
- A directional level may exist while price remains outside it, in which case the strategy stays in a waiting state rather than chasing price.
- NO TRADE bias makes pullback analysis explicitly not applicable.
- Broken/invalidated levels are excluded from pullback qualification.
- Exact zone-boundary contact counts as entering the pullback zone, consistent with the Phase 3 level-touch contract.
- When several directional zones are touched by the same candle, the nearest zone midpoint to the candle close is selected; equal-distance ties prefer the newer level.
- Added explicit pullback states/reasons so later setup logic can distinguish waiting, in-zone, and non-applicable conditions.
- A detected pullback is market context only and is deliberately not an entry confirmation or BUY/SELL trigger.

### Phase 4 — Multi-timeframe trading bias foundation

- Started the standalone `strategy_engine` package with a one-way dependency on `technical_analysis`.
- Added deterministic H4/H1 trading-bias alignment: bullish + bullish => BUY bias; bearish + bearish => SELL bias.
- Conflicting H4/H1 structures produce NO TRADE.
- NEUTRAL or UNKNOWN on either H4/H1 produces NO TRADE, with explicit machine-readable reasons.
- D1 structure is retained as optional market context but deliberately does not gate direction in this baseline.
- Added convenience guards for whether the strategy may look for BUY, SELL, or should stand aside.
- Added tests covering bullish alignment, bearish alignment, both conflict directions, NEUTRAL, UNKNOWN, and non-gating D1 context.
- No pullback, entry confirmation, Entry/SL/TP, RR, score, or AI logic has been added yet.

### Phase 3 — Integration regression test correction

- Corrected the Phase 3 integration fixture expectation: nearby same-type swing-derived zones are intentionally merged by `KeyLevelMerger`, so the fixture produces one resistance and one support level (2 total), not four raw levels.
- Added an explicit assertion that the integrated snapshot contains both support and resistance after merging.
- Production analysis logic was not changed; the failing assertion was inconsistent with the already-tested level-merging contract.

### Phase 3 — Integrated level and liquidity analysis snapshot

- Added `LevelLiquidityAnalyzer` to compose the existing Phase 3 primitives into one deterministic analysis snapshot for a closed candle.
- The analyzer converts confirmed swings into key levels, merges compatible levels, detects equal-high/equal-low liquidity pools, and reports current-candle key-level and liquidity-pool sweeps.
- Added immutable `LevelLiquidityAnalysis` output containing key levels, liquidity pools, level sweeps, and pool sweeps.
- Kept all calibration values explicit: key-level zone half-width, level merge gap, and equal-price tolerance remain caller-provided.
- Added integration tests for the full analysis path, level merging, empty input, immutable output, and invalid calibration inputs.
- This integration layer deliberately does not decide trend, setup quality, BUY/SELL, Entry, SL, TP, or AI confidence.

### Phase 3 — Liquidity pool lifecycle

- Added explicit `active`, `swept`, and `broken` lifecycle states for equal-high/equal-low liquidity pools.
- Equal-high pools transition to `swept` after a raid above the pool followed by a close back at/below the upper boundary, or to `broken` after a close above the pool.
- Equal-low pools transition symmetrically to `swept` after a raid/reclaim, or to `broken` after a close below the pool.
- Ordinary interactions leave a pool active.
- `swept` and `broken` are terminal states in this baseline so consumed/invalid liquidity is not reused by later analysis.
- Added focused lifecycle tests for both pool types and terminal-state behavior.
- This remains deterministic market evidence and does not produce BUY/SELL, Entry, SL, TP, BOS/CHoCH, or setup scoring.

### Phase 3 — Liquidity pool sweep / raid detection

- Added `LiquidityPoolSweepDetector` for deterministic single-candle raids of equal-high and equal-low liquidity pools.
- An equal-high raid requires price to trade strictly above the pool upper bound and then close back at or below that boundary.
- An equal-low raid requires price to trade strictly below the pool lower bound and then close back at or above that boundary.
- Added explicit `aboveEqualHighs` and `belowEqualLows` directions with the raid extreme and candle close price.
- Exact boundary touches without exceeding the pool are not raids; an exact-boundary close after a true raid counts as a reclaim.
- Added focused tests for both directions, successful/failed reclaims, exact-boundary reclaims, and non-raid boundary touches.
- Kept liquidity evidence separate from strategy decisions: this increment does not produce BUY, SELL, Entry, SL, or TP.
- Did not add multi-candle reclaim, pool lifecycle/consumption, sweep strength, BOS/CHoCH, or setup scoring.

### Phase 3 — Equal-high / equal-low liquidity pools

- Added `EqualSwingLiquidityDetector` to identify liquidity pools formed by two or more confirmed swing highs or confirmed swing lows at approximately equal prices.
- Added explicit `equalHighs` and `equalLows` pool types with price-zone bounds, midpoint, originating swing indexes, and swing count.
- Kept XAUUSD equality tolerance caller-provided instead of introducing an uncalibrated fixed distance.
- Required the full price span of a cluster to stay inside tolerance, preventing chained price drift from incorrectly creating a large equal-price pool.
- Kept swing highs and swing lows strictly separated.
- Added focused tests for equal highs, equal lows, tolerance boundaries, out-of-tolerance prices, type separation, chained-drift prevention, and invalid tolerance values.
- Did not add pool sweep/raid detection, liquidity strength scoring, BOS/CHoCH, BUY/SELL, Entry, SL, or TP logic.

### Phase 3 — Baseline liquidity sweep detection

- Added `LiquiditySweepDetector` as the first deterministic liquidity-analysis primitive.
- A support sweep requires price to wick strictly below the support zone and the closed candle to reclaim by closing back at or above the zone's lower boundary.
- A resistance sweep requires price to wick strictly above the resistance zone and the closed candle to reclaim by closing back at or below the zone's upper boundary.
- Added explicit `belowSupport` and `aboveResistance` sweep directions plus captured extreme and close prices.
- Kept ordinary touches, unreclaimed pierces, and confirmed breaks separate from liquidity sweeps.
- Prevented inactive key levels from generating sweep events.
- Added focused tests for support/resistance sweeps, exact-boundary reclaims, failed reclaims, ordinary touches, and inactive levels.
- Did not add sweep strength, multi-candle reclaim, equal-high/equal-low liquidity pools, BOS/CHoCH, BUY/SELL, Entry, SL, or TP logic.

### Phase 3 — Key level lifecycle transition

- Added `KeyLevelLifecycle` to apply already-classified break events without mixing market-event detection with domain state transitions.
- A `confirmedBreak` now transitions an active key level to `broken`.
- `wickPierce` and `none` leave an active level unchanged.
- Existing `broken` and `invalidated` levels remain terminal for this baseline transition and are not revived by later break results.
- Preserved level type, source, price-zone bounds, and originating candle index when transitioning to `broken`.
- Added focused tests for confirmed breaks, wick pierces, no-break events, already-broken levels, and invalidated levels.
- Did not implement support/resistance role reversal, reclaim/fakeout logic, invalidation policy, liquidity sweeps, BOS/CHoCH, or trading signals.

### Phase 3 — Level break detection

- Added `LevelBreakDetector` to distinguish no break, wick-only pierce, and confirmed key-level break on closed candles.
- A support break requires the candle close below the zone's lower boundary; a resistance break requires the close above the upper boundary.
- A wick extending beyond the zone without a confirming close is classified separately as `wickPierce` instead of a confirmed break.
- Added optional explicit `closeBuffer` support without hard-coding an uncalibrated XAUUSD/ATR threshold.
- Prevented inactive levels from producing new break events.
- Added focused tests for support/resistance breaks, wick-only pierces, exact boundary closes, close buffers, inactive levels, and invalid buffers.
- Did not mutate `KeyLevel` lifecycle state yet; break detection and state transitions remain separate responsibilities.
- Did not add fakeout/reclaim logic, liquidity sweeps, BOS/CHoCH, or trading signals.

### Phase 3 — Baseline level strength evaluation

- Added `LevelStrengthEvaluator` using independent touch-event count rather than raw touching-candle count.
- Added baseline states: `untested`, `weak`, `established`, and `wellTested`.
- Defined 0 events as untested, 1 as weak, 2 as established, and 3+ as well tested.
- Kept this classification intentionally narrow: it is not a trading score and does not yet include rejection quality, recency, volatility, break history, or higher-timeframe confluence.
- Added tests proving a long continuous interaction remains one event and therefore cannot artificially inflate level strength.
- Did not add BUY/SELL decisions, signal confidence, liquidity scoring, or strategy logic.

### Phase 3 — Independent level-touch events

- Added `LevelTouchEventDetector` to group consecutive candle-level touches into one independent interaction with a key-level zone.
- A new independent touch event starts only after at least one non-touching candle separates it from the previous event.
- Added `LevelTouchEvent` with start/end candle indexes, raw touch count, and event duration.
- Added validation requiring raw touch indexes to be unique and strictly increasing.
- Added focused tests for continuous contact, separated interactions, single touches, empty input, duplicate indexes, and out-of-order input.
- Kept this layer independent from rejection quality and level-strength scoring; three consecutive candles inside one zone now remain one event rather than three independent tests.
- Did not add strength scores, rejection confirmation, break/invalidation transitions, liquidity pools, or trading signals.

### Phase 3 — Key level touch detection

- Added `LevelTouchDetector` to identify when a closed candle's full high/low trading range intersects an active support or resistance zone.
- Counted exact zone-boundary contact as a touch and supported wick-only contact without requiring the candle close to enter the zone.
- Kept touch detection separate from rejection/confirmation quality so later strategy logic can distinguish simple contact from valid confirmation.
- Added indexed batch detection with an explicit start candle index for future post-creation touch counting.
- Prevented broken or invalidated levels from producing active touches.
- Added focused tests for support/resistance contact, wick contact, outside candles, boundaries, inactive levels, batch indexes, and invalid start indexes.
- Did not add touch deduplication, level strength scoring, rejection confirmation, break/invalidation transitions, liquidity pools, or trading signals.

### Phase 3 — Key level merging foundation

- Added `KeyLevelMerger` to consolidate overlapping or nearby active support/resistance zones of the same type.
- Added explicit `maxGap` configuration instead of hard-coding an uncalibrated XAUUSD merge distance.
- Preserved support/resistance separation and prevented inactive levels from being merged into active zones.
- Merged zones retain the earliest originating candle index and expand only to cover the combined price area.
- Added chained merging so several nearby levels can become one consolidated zone.
- Added focused tests for overlap, proximity, separation, type safety, inactive levels, chained merging, and invalid merge distances.
- Did not add touch counts, level strength, break/invalidation transitions, liquidity pools, ATR sizing, or trading signals.

### Phase 3 — Confirmed swing to key-level generation

- Added `KeyLevelFactory` to deterministically convert already-confirmed swing highs into resistance zones and confirmed swing lows into support zones.
- New levels start in the `active` state and retain the originating confirmed swing candle index.
- Kept zone sizing explicit through `zoneHalfWidth`; no arbitrary XAUUSD zone-width constant was introduced before ATR/volatility calibration.
- Added batch generation while preserving confirmed swing order.
- Added focused tests for resistance/support generation, exact zero-width levels, batch ordering, invalid widths, and invalid negative price zones.
- Did not implement level merging, touch counting, strength scoring, break/invalidation transitions, liquidity pools, or trading signals.

### Phase 3 — Key level domain model

- Added the first Level & Liquidity Engine primitive: a deterministic `KeyLevel` price-zone model.
- Added explicit support and resistance level types.
- Added swing-high and swing-low origins, with validation that resistance originates from swing highs and support originates from swing lows.
- Added active, broken, and invalidated lifecycle states without implementing transition rules yet.
- Represented levels as lower/upper price zones instead of pretending every support or resistance has exact single-price precision.
- Added midpoint, width, containment, and active-state helpers.
- Added validation and focused unit tests for bounds, source/type consistency, origin candle index, and price containment.
- Did not implement automatic level detection, merging, touch counting, break confirmation, liquidity logic, BOS, CHoCH, or trading signals.

### Phase 2 — Integrated market structure test fixture correction

- Corrected the integration-test candle fixtures so bullish, bearish, and equality scenarios each contain two independently confirmed swing highs and two independently confirmed swing lows.
- Preserved the production `MarketStructureAnalyzer` implementation because the failing assertions were caused by insufficient synthetic pivot history rather than analyzer logic.
- Kept the 2-left / 2-right confirmation rule unchanged and avoided weakening production rules merely to satisfy tests.

### Phase 2 — Integrated market structure analysis

- Added `MarketStructureAnalyzer` to connect the existing closed-candle, confirmed-swing, swing-relationship, and market-structure components into one deterministic pipeline.
- The analyzer now derives the latest confirmed high and low relationships from candle data and returns bullish, bearish, neutral, or unknown structure.
- Preserved the explicit caller-provided equality tolerance until XAUUSD quote precision is calibrated.
- Added an immutable analysis result containing confirmed swings, latest high/low relationships, and final structure.
- Added integration tests for bullish, bearish, neutral/equality, insufficient-data, and invalid-tolerance scenarios.
- Kept BOS, CHoCH, trading bias, BUY/SELL, Entry, SL, TP, AI, and Firebase outside this increment.

### Phase 2 — Market structure classification

- Added `MarketStructure` states: `bullish`, `bearish`, `neutral`, and `unknown`.
- Added deterministic classification where HH + HL is bullish and LH + LL is bearish.
- Classified every other complete and valid high/low relationship combination as neutral.
- Kept insufficient relationship data explicitly distinct as unknown instead of treating it as a neutral market.
- Added validation preventing high relationships and low relationships from being supplied in the wrong role.
- Added focused tests for bullish, bearish, neutral, unknown, and invalid relationship inputs.
- Did not introduce range detection, BOS, CHoCH, strategy signals, Entry, SL, TP, or AI logic.

### Phase 2 — Swing relationship classification

- Added deterministic comparison of consecutive confirmed swings into HH, LH, EH, HL, LL, and EL relationships.
- Kept equal-high/equal-low tolerance explicit at the call site because the XAUUSD equality tolerance is not globally calibrated yet.
- Added validation that only same-type, chronological swing points can be compared.
- Added tests for all six relationship outcomes, tolerance boundaries, chronology, type safety, and invalid tolerances.
- Did not add market-structure state, BOS, CHoCH, signals, or trading decisions in this increment.

### Phase 2 — Market structure foundation: confirmed swing detection

- Added the standalone `technical_analysis` Dart package with a dependency only on `market_models`.
- Added `SwingPoint` and `SwingType` domain primitives for confirmed swing highs and lows.
- Added a deterministic `SwingDetector` using the locked 2-left / 2-right pivot rule by default.
- Enforced strict high/low comparisons so equal neighboring prices do not qualify as pivots.
- Ensured a candidate pivot is not emitted until both required right-side closed candles are present, preventing look-ahead.
- Added focused unit tests for swing highs, swing lows, confirmation timing, strict equality behavior, and insufficient data.

### Phase 1 — Market data foundation: Candle model

- Added the standalone `market_models` Dart package as the first trading-domain package.
- Added an immutable OHLCV `Candle` model with open/close timestamps.
- Added validation for candle time ordering, finite/non-negative numeric data, and OHLC price relationships.
- Added derived candle properties for bullish, bearish, doji, total range, and body size.
- Added focused unit tests for valid candles and invalid market-data inputs.
- Kept the market model independent from Flutter, Firebase, AI, strategy, and UI layers.

### Web dependency resolution fix

- Added the Flutter SDK `flutter_web_plugins` package as an application dependency.
- Restored successful Flutter Web plugin registration for the Firebase Core web implementation.
- Verified the baseline with `flutter analyze`, `flutter test`, and `flutter run -d edge`.
- Confirmed TradeForge V2 launches successfully on Microsoft Edge.

### Baseline verification fix

- Updated the generated Flutter widget test to use `TradeForgeApp` instead of the removed `MyApp` counter-template class.
- Added a minimal application-shell render assertion for `TradeForge V2`.

### Firebase application bootstrap

- Initialized Firebase before the Flutter application starts.
- Wired the generated `DefaultFirebaseOptions` into `Firebase.initializeApp`.
- Replaced the default Flutter counter demo with the minimal TradeForge V2 application shell.
- Disabled the debug banner and established the initial Material 3 application theme.
