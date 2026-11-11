# ComfyUI Diagnostics Monitor v0.8.0 LAB CANDIDATE — Release Notes

Status: **LAB / NOT PRODUCTION**. Windows CI is required on the exact release commit; real HOME/WORK sustained runtime and Defender/SmartScreen tests remain pending.

## Added
- Unsigned GUI `ComfyUI-Diagnostics-Setup-v0.8-LAB.exe` (HOME/WORK selector; delegates to PowerShell installer).
- Double-click `Install-or-Update.bat` fallback with profile selection and confirmation.
- **Open Logs Folder** shortcut in Dashboard and Configurator for local `telemetry/events/live/evidence` files.
- GPU / VRAM live right-aligned percent legend; CPU/RAM series and 3ds Max working-set memory.
- Dashboard/HUD dark graphite UI consistency and native form anchoring.
- Startup background GitHub release metadata check; user-confirmed manual install.
- PowerShell upgrade retains existing `comfy_log` path when caller does not replace it.

## Compatibility and limitations
- Windows 10/11 x64, Windows PowerShell 5.1 and optional NVIDIA SMI.
- User diagnostic data remains outside installation directory and is preserved by the project uninstall tool.
- No driver, ComfyUI, model, GPU reset, TDR registry or system stress operation.
- No signed executable, auto-download/auto-install, guaranteed crash root-cause analysis, or production reliability claim.
- The Collector currently requires manual start; long-running retention, single-instance and sleep-resume scenarios remain candidates for v0.8.x hardening.

## Rollback
Stop GUI/Collector and re-run the prior validated v0.7 installer ZIP/EXE with upgrade, after confirming the installed source and preserving diagnostic data. Current upgrade is not an atomic transaction; do not claim crash-proof rollback.

## Validation gates
Syntax, Windows GUI smoke/HUD, source telemetry regressions, install/uninstall retention, ZIP integrity and actual EXE install/uninstall verification on ephemeral Windows CI. Any missing or failing gate blocks merge/release.
