# Windows UI Consistency Fix — LAB Candidate

**Branch:** `ui/winforms-consistency-v07-20261110`  
**Base:** v0.7 Draft PR #12, `968c785c055ad9ecfeabe6c833858afb631aee69`  
**Status:** NOT PRODUCTION; UI layout on actual HOME/WORK DPI must be visually accepted.

## Intent and design

Scope is deliberately limited to WinForms presentation: Dashboard and Configurator. Retain existing information hierarchy and controls while improving consistency with the approved dark graphite / Segoe UI design language. The primary Capture Evidence action is yellow (`#FFD400`), secondary buttons are charcoal. GPU curves remain cyan and VRAM curves orange (semantic colors, no reassignment).

**Current → change → rationale:**

- Dashboard caption previously showed legacy `LAB v0.4`, Configurator caption `LAB v0.6` despite installing v0.7 → read the installed manifest version if present; fallback `0.7.0-LAB-CANDIDATE` for unpackaged source runs → eliminate misleading window labels without changing installer versioning.
- Basic WinForms buttons with inconsistent background/borders → coherent FlatStyle, focusable native buttons, hand cursor, explicit normal/hover/pressed colors, visible primary vs. secondary action → match desktop design while preserving click actions and keyboard operation.
- Inconsistent window panels, backgrounds, headers and input fields → common graphite palette and Segoe UI, muted subtitle, improved heading hierarchy → legibility/consistency.
- In the existing PowerShell 5.1 Dashboard, Unicode em dash may appear as mojibake when source encoding is interpreted incorrectly → replace placeholder em dashes only with ASCII `-` → stable idle presentation; no change to event parsing or telemetry.

## Non-goals and protected baseline

- No edits to `collector.ps1`, `evidence.ps1`, HUD source, NVIDIA/ComfyUI, models, settings, startup, telemetry schema, update checker, retention, or Windows registry.
- No automatic merge, uninstall/upgrade, reinstallation, or external data transfer.
- Current window sizes, placements, actions, graph series and GPU cyan/VRAM orange colors intentionally retained. This is a controlled **UI fix**, not the planned full v0.9 UI redesign or single-window application architecture.
- Installed HOME/WORK v0.7 binaries remain unchanged until the user manually tests a new ZIP.

## Validation gates

- Windows PowerShell 5.1 parsing of Dashboard, Configurator and the unchanged source.
- Windows Dashboard startup and HUD show/hide/restore smoke tests; Configurator initialization and CaptureSelfTest; original WebSocket and Evidence tests.
- Windows installer packaging, icon and data preservation.
- Visual manual tests **still required**: default and 125%/150% scaling, both buttons hover/pressed/focus/disabled; labels and active-node idle placeholder; screen edge clipping; Dashboard ↔ HUD F9; Configurator Snapshot; screenshots on HOME/WORK.
- Rollback to the verified v0.7 Windows CI artifact prior to this UI branch, without erasing `%LOCALAPPDATA%\ComfyUI-Diagnostics` data.

**STOP** if Capture Evidence button fails, HUD shortcut breaks, model/driver behavior changes, clipped UI appears on actual Windows DPI, or visual controls become inaccessible. Do not mark UI PRODUCTION from CI alone.
