# Dashboard / HUD UI Consistency Pass — LAB

**Base:** Draft PR #14 `ce7e1d62a36c1d02163c13283194e63c0da79ff0` (live GPU/VRAM legend).  
**Status:** Windows CI gate required; HOME/WORK high-DPI screenshots NOT TESTED. NOT PRODUCTION.

## Scope

- Dashboard: preserve original 960×740 design, telemetry and series names. Add native WinForms anchors for resizable graph, labels, buttons and timeline; align colored statuses (green active, amber stale/unavailable); muted secondary labels; native right-docked numerical legend.
- HUD: preserve drag, F9/double-click restore, chart series bindings; create a 420×200 graphite panel with branded header, unchanged cyan/orange GPU/VRAM traces, read-only status text and greater spacing.
- Configurator: align status colors, native Font scaling, text truncation and input anchoring without changing Evidence snapshot semantics.

## Protected

No code change to collector, evidence, ComfyUI, Windows events, telemetry schema, dependencies, GPU drivers, rendering models or workflows. No memory cleaner. No background service/startup.

## CPU/RAM scope discovery

The existing collector v0.3 samples `ram.used_mib` / `ram.total_mib` with `Win32_OperatingSystem`, but **does not sample CPU load** or per-process `3dsmax.exe` memory. Existing one-shot Evidence captures CPU snapshot separately. Adding CPU/RAM charts and 3ds Max/Corona memory monitoring is therefore a separately scoped telemetry-extension change with schema-compatible optional fields, source status and tests; do not fabricate current values from cached snapshots or reuse VRAM as RAM.

## Validation

PowerShell parser, existing Dashboard/Configurator smoke, HUD show/hide/restore, Evidence regression, Windows installer and SHA256 inventory must pass at the exact head. Manual HOME/WORK at 100%, 125% and 150% scaling, enlarged window, legend clipping, HUD drag/F9, long labels, read-only status changes and no loss of Capture Evidence action remain acceptance gates.

**STOP:** broken HUD switching, chart series changed, private data exposed, unusable controls at high DPI, unexpected ComfyUI mutation or any Windows regression. Revert to PR #14 candidate ZIP; installed diagnostic data stays independent.
