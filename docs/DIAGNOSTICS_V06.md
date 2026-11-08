# ComfyUI Diagnostics Evidence Center v0.6 · LAB

## What ships
Existing GPU Collector + Dashboard/HUD remain unchanged. New modules:
- **Configurator**: manually select local evidence capture (Windows/WER/Reliability, Python process metadata, storage, ComfyUI).
- **Evidence CLI**: `evidence.ps1`, accepts HOME/WORK, 1–24 hour Windows window, source disable switches, log path and optional `-ArchiveComfyLog` (off by default).
- **Private evidence archive**: `%LOCALAPPDATA%\ComfyUI-Diagnostics\evidence\evidence_HOME_<timestamp>_<id>.json`. New writes only, no deletion/overwriting existing v0.3 JSONL.
- **Tests**: Windows PowerShell parser, Configurator startup, bounded on-demand capture fixture, Windows ZIP install/uninstall/data retention.

## Capture and read
From installed Start Menu **ComfyUI Diagnostics LAB → Configurator**, click **Capture Evidence**; choose the read-only source toggles. Alternatively from installed folder:
```powershell
.\evidence.ps1 -Machine HOME -ComfyLog "Q:\AI_ArchViz\ComfyUI_windows_portable\ComfyUI\user\comfyui.log"
```
In ChatGPT Work, authorize local folder on request and inspect `evidence\*.json`. Do NOT upload files publicly. To verify CI without ComfyUI/GPU:
```powershell
.\evidence.ps1 -Machine HOME -DataRoot "$env:TEMP\DiagnosticTest" -SkipWindows -SkipProcesses -SkipStorage -SkipComfy -SelfTest
.\configurator.ps1 -Machine HOME -SelfTest
```

## Data coverage and honest limits
- GPU: sampled nvidia-smi util, memory, temperature, power, clocks and P-State when available.
- CPU: CIM logical processors and load percentage (may be null/unsupported). Process snapshots list **Python candidates** without claiming they belong to ComfyUI.
- RAM: physical and virtual memory totals/free via CIM.
- Storage: fixed logical volumes' total/free capacities, no disk identifiers in exported file.
- Windows: System and Application warning/error events (filter relevant providers), up to 100 results per log from recent 1–24h. No raw event message; provider/code/time/record id/level.
- Reliability: WMI `Win32_ReliabilityRecords` when available, normalized identifiers, no message strings.
- ComfyUI: localhost queue size, selected error signature codes from last 1500 lines; no raw prompts or trace text. Local SHA256 of source log for integrity.
- Unknown sources are **UNAVAILABLE**, not zero. WER full report contents, minidumps, CPU temperature, GPU errors not captured by Windows, per-node GPU attribution and actual ComfyUI execution events remain **NOT IMPLEMENTED**.
- Event correlation is **not a proven root cause**. Kernel-Power 41 is a consequence marker, not necessarily the primary fault.
- `SelfTest` includes a clearly labeled synthetic Display 4101 fixture; it does not induce GPU failure.

## Privacy, quotas, failure modes
Evidence is local-only and no auto-upload occurs. Paths are not written to evidence, other than source folder metadata through local config. Selected signals are normalized; raw Windows/ComfyUI messages and Python command lines excluded. Machine alias HOME/WORK only. Evidence capped at 3 MiB per snapshot, 300 snapshots / 100 MiB evidence directory limit; STOP instead of deleting old evidence. The existing v0.3 continuous collector retains its own older limitations and remains under supervised operation.

**STOP** on GPU instability, privacy incident, unexpected large file growth, missing permission, false claims about ComfyUI process ID or unexplained failures.

## Installation
LAB user-level ZIP, *not signed EXE/MSI*. SHA-256 and file manifest produced in GitHub Actions; verification of HOME browser/Defender warning and installed runtime still required. Use `install.ps1 -Machine HOME -Upgrade -ComfyLog <known_path>` only after checking new ZIP, stopping old GUI/Collector and ensuring installed data backup. Do not bypass browser/Defender alerts.

## Simulation acceptance matrix
1. CUDA OOM: normalize CUDA/OOM signature + GPU/VRAM + environment available; **cannot prove cause without full traceback**.
2. GPU TDR: Windows Display/WHEA + related Reliability event + GPU history from v0.3; last seconds may be missing.
3. Custom node: normalized exception/import errors; full traceback remains private, needs reviewed on-demand source reading.
4. Slow render: GPU/CPU snapshots; per-node latency NOT IMPLEMENTED.
5. Unexpected restart: Kernel-Power/BugCheck/WER where OS retains records; cause may remain unknown.
6. Offline ComfyUI/NVIDIA: explicit source UNAVAILABLE, no fabricated readings.
7. Integrity: unique snapshots, quota, installer retention tests; old JSONL never altered.

**Current status: FEATURE CANDIDATE / CI TESTS REQUIRED / HOME NOT TESTED.** Do not claim PRODUCTION.

## Optional private full ComfyUI logs
The Configurator offers an **unchecked opt-in** to archive the exact local raw ComfyUI log under `DataRoot\private`. Raw logs can contain client prompts, private paths, API keys and other sensitive data, so the checkbox is not automatic and the user must review files before granting ChatGPT Work access. Individual files capped at 20MiB; folder capped at 20 logs / 200MiB. Failed copy leaves a normalized UNAVAILABLE source; nothing is uploaded.

## Windows brand icon + artifact packaging fix (2026-11-09)
The generated Windows icon is a locally generated original cyan waveform with orange status dot on a dark monitor background. `lib/AppIcon.ps1` generates `app.ico` with 32x32, 48x48, and 256x256 image entries at installation time; the icon is used by the Dashboard title/taskbar, notification tray, HUD window metadata, Configurator, and Start Menu shortcuts. No third-party font or binary asset is distributed.

**Root cause of the broken v0.6 download**: first v0.6 GitHub Actions artifact uploaded old `v0.5` filenames (which no longer existed) and only `package-manifest.json`. Corrected upload to exactly `ComfyUI-Diagnostics-LAB-v0.6.zip`, `ComfyUI-Diagnostics-LAB-v0.6.sha256`, `package-manifest.json`. CI now extracts the inner ZIP and checks for `install.ps1`, `dashboard.ps1`, `configurator.ps1`, `lib/AppIcon.ps1` and the ZIP checksum before upload.

**CI evidence**: Windows package run `42532468182` PASS, icon generated and parsed by Windows .NET, ZIP expanded and checksum matched; actual HOME/WORK taskbar/tray visual correctness remains NOT TESTED until user screenshots. Previously downloaded small artifact is BROKEN; re-download artifact from the corrected CI run. No `main` merge or Production Release.
