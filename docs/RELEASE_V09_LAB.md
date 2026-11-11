# ComfyUI Diagnostics Monitor v0.9.0 — Unified UI LAB

**Status:** LAB CANDIDATE / NOT PRODUCTION. Windows CI required on exact head; HOME RTX 3070 Ti and WORK RTX 4090 acceptance not yet done.

## What changed

- One **Monitor** Start Menu shortcut launches a single Windows Forms desktop process, with four tabs: **Монитор / Генерации / Диагностика / Настройки**, English optional.
- A managed Collector starts automatically in an **in-process background runspace**, not a separate visible console. A named per-machine mutex prevents launching a second managed Collector from another v0.9 UI instance. The mutex cannot detect a manually started legacy v0.8 Collector; close legacy Collectors before using v0.9.
- CPU, RAM, GPU and VRAM cards and history chart; 3ds Max working set and basic ComfyUI API availability.
- Normalized WebSocket node ID, execution state and sampler progress are read-only; no private prompt archival. Offline ComfyUI is an acceptable state.
- **Диагностика** tab invokes existing local Evidence capture on explicit button click and opens the logs/evidence folders.
- **Настройки** saves RU/EN language in `%LOCALAPPDATA%\ComfyUI-Diagnostics\ui-settings.json` and retains version-check action. No automatic unsigned update execution.
- Existing HUD via F9/minimize retained; tray icon restores window.
- The legacy scripts are retained for backward compatibility and CI. The installer creates only a new Monitor shortcut and removes its own older shortcuts.

## Not implemented / gated

- **Clear ComfyUI cache:** button disabled until an idle guard, exact ComfyUI API version, risk analysis and real testing. Never clear OS RAM or forcibly reset GPU.
- Full model/seed/CFG/prompt and image galleries: not asserted without a tested, opt-in /history and /view integration. The Generations tab currently shows normalized live event history and active node ID, not inferred custom node titles, saved prompts or image previews.
- Fully atomic executable upgrades, silent unsigned installation, signed binaries, Windows service and startup tasks.
- Real HOME/WORK screenshots, high DPI and collector lifetime evidence.

## Acceptance

- Exact-head Windows CI: PowerShell parse including `unified.ps1`, unified `-SelfTest` (four tabs, RU/EN, disabled cache button), existing HUD/Evidence regressions, EXE compile and installation / ZIP SHA-256.
- On HOME: start only Monitor; no PowerShell or duplicate collector windows; collector transitions to ACTIVE and historical GPU/VRAM/CPU/RAM chart plots where sources available; 3ds Max / ComfyUI OFFLINE states are honest. F9, tray, Capture Evidence and Open Logs work.
- Close Monitor and verify no managed collector remains; data preserved; interface language persists on relaunch.
- Failure in UI, missing data, blocked shutdown, GPU crash or ComfyUI mutation = **STOP**. Reinstall the published v0.8.0 LAB EXE to roll back; backup local diagnostic data first.

This release is for user acceptance only, never silently distributed as Production.
