# Increment 221 Fix — Historical ExpansionTile Web State

Makes every Frozen Paper Historical `ExpansionTile` use an explicit stable
segment key and explicit non-persistent collapsed state.

This avoids reusing incompatible ExpansionTile/PageStorage state left by web
hot reload while the Historical tab structure changed.

After applying this fix, stop the existing Flutter web process and launch a
fresh Edge session instead of relying on hot reload.
