# Always-on-top transparent HUD — LAB v0.5

This feature adds an optional GPU/VRAM performance HUD to the existing Windows Dashboard. It does not alter the collector, models, drivers or ComfyUI.

## Controls

- The full dashboard stays **TopMost** by default (normal Windows applications, not guaranteed over exclusive fullscreen, secure desktop or UAC).
- Click **HUD (F9)** or minimize the full dashboard to enter compact mode.
- The HUD draws white technical readings and blue/orange GPU/VRAM traces on a transparency-key background (no panel). It is always on top, positioned near the upper-right corner of the primary monitor by default.
- **Drag with left mouse button** to move the HUD.
- **Double-click** the HUD or press **F9** while it has focus to restore the full dashboard.
- Full dashboard remains the source of live telemetry, ComfyUI events and incident timeline. HUD only visualizes existing state; the collector must be running to show fresh GPU samples.
- HUD is interactive (not click-through) so it can be moved and restored; click-through is not included in this version. Transparent pixels should normally pass through, but behavior must be tested on HOME and WORK.

## Privacy, security and test gates

All data remains on the computer. No new package dependencies or upload endpoints.

Windows CI must PASS PowerShell parsing (including lib/Hud.ps1), WebSocket redaction tests, SQLite tests, and dashboard `-SelfTest` including TopMost/transparency configuration. CI does not establish that the HUD renders, drags or restores correctly.

HOME/WORK acceptance:
1. Full dashboard stays in front of ordinary ComfyUI/browser windows.
2. Click HUD (F9), confirm compact overlay and transparent background with GPU/VRAM graphs.
3. Drag HUD, verify it remains on top but does not block unrelated applications beyond its interactive content.
4. Double-click overlay to restore, verify previous full dashboard and WebSocket remain responsive.
5. Minimize full dashboard to enter HUD, then restore. No duplicate windows or orphan PowerShell process.
6. Turn off collector and confirm data freshness is not misrepresented.
7. **STOP** if black screen, GPU hang, loss of ComfyUI data or keyboard focus problems occur.

Known limitations: transparency-key is not guaranteed over exclusive-fullscreen games or protected windows. UI runtime is NOT TESTED until screen/host verification; screenshot and sample outputs from HOME/WORK are required. Background is transparent by exact magenta key rather than per-pixel alpha; anti-aliased edges may exhibit color artifacts.
