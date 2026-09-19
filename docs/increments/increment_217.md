# Increment 217 — Unified Forward Performance Foundation

## Goal
Track new resolved A/B/C5 forward trades under one performance standard without mixing historical baseline or Segment research evidence.

## Changes
- Added `UnifiedForwardPerformanceAdapter`.
- Joins resolved results to the original formal `PaperSignal` for authoritative side and observation time.
- Counts only finite realized-R outcomes.
- Restricts production aggregation to A/B/C5; Segment research remains separate.
- Added CLI `xauusd_unified_forward_performance.dart`.
- Added coverage for A/B/C5 aggregation, unresolved exclusion, and orphan-result integrity failure.

## Lifecycle invariant
Candidate/READY state is not a user-facing trade. Only formal triggered signals may enter forward trade performance. Pre-trigger invalidation/expiry is not a win/loss and is not included in trade metrics.

## Evidence separation
Historical 2024–2026 baseline, A/B/C5 forward evidence, and Segment paper research remain separate datasets and must not be merged into one headline win rate.

## Validation
Run from `research/backtesting`:

```powershell
dart format .
dart analyze
dart test
dart run bin/xauusd_unified_forward_performance.dart ".paper_forward"
```
