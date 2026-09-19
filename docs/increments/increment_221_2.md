# Increment 221.2 — Web-safe Historical Expansion

Replaces Flutter `ExpansionTile` in Frozen Paper Historical cards with a
small locally controlled `StatefulWidget`.

Why:
- the Edge/web runtime was failing inside `ExpansionTile` state restoration
  with a `double` being cast to `bool?`;
- historical metrics themselves were valid;
- stable keys/PageStorage mitigation did not remove the runtime failure.

Behavior:
- cards remain collapsed by default;
- tapping the header toggles a local boolean;
- 2025/2026 rows appear only when expanded;
- no `ExpansionTile`, `ExpansibleController`, PageStorage expansion state, or
  animated expansion state is used;
- Increment 220 historical values are unchanged.
