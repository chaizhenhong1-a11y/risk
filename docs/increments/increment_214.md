# Increment 214 — Wire Sample Quality into Paper Forward Report

The real paper-forward performance CLI now prints the shared sample-quality
assessment for every Overall, strategy, and BUY/SELL breakdown.

Example:

    C5
      sample=INSUFFICIENT SAMPLE (5/30 minimum)
      trades=5 W=3 L=2 BE=0
      win=60.00% E=0.800R PF=3.000
      total=4.000R maxDD=2.000R

The label is reporting context only. It does not modify performance metrics,
strategy rules, candidate validity, or execution eligibility.
