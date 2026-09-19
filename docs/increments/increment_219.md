# Increment 219 — Strategy Performance UI

Adds a dedicated Statistics tab to the Flutter app.

## UI
- Overall Performance at the top.
- Production Forward total performance.
- Paper Forward total performance.
- Per-strategy forward cards.
- 2024–2026 Historical Baseline cards.
- Total win rate is always shown per evidence layer.
- Historical / Paper / Production are never merged.

## Current historical display baseline
- A: 87 resolved, 35W/52L, 40.23%, +0.455R expectancy, PF 1.762.
- B: 4 resolved, 0W/4L, research-only and insufficient sample.
- C5: 108 resolved, 44W/64L, 40.74%, +0.222R expectancy, PF 1.375; 49 expired historical cases remain noted.

Forward values are calculated from the app's actual resolved signal history. No
fake forward result is inserted.

## Validate
```powershell
cd "C:\flutter project\tradeforge_v2\apps\mobile"
dart format .
flutter analyze
flutter test
```
