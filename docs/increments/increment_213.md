# Increment 213 — Performance Sample Quality

Adds reporting-only sample maturity:

- <30 trades: INSUFFICIENT SAMPLE
- 30–99: EARLY SAMPLE
- 100–299: DEVELOPING SAMPLE
- >=300: ESTABLISHED SAMPLE

This is context only. It does not approve/reject a strategy, change metrics,
alter trading rules, or become a trading gate.

The formatter is intentionally separate so the CLI/UI can consume the same
sample-quality semantics in the next wiring step.
