# v0.9.0 Unified Control Center — LAB CANDIDATE

**Base:** v0.8.0 LAB v0.8 source-of-truth on main, commit `8955028343233457ad992864d351356f121b0350`.

## Shipped in this branch
- One **Windows WPF application** containing Monitor, Generations, Diagnostics, Settings in the same window.
- Modern graphite dark theme; large system counters; GPU cyan, VRAM orange, CPU green, RAM violet; scalable vector WPF UI.
- Localized RU (default) and EN; preference `%LOCALAPPDATA%\ComfyUI-Diagnostics\ui-settings.json` survives app upgrades.
- Start Menu has one launch shortcut. Collector starts as one **hidden** child process, is protected by a named per-profile mutex and stops only when its owning UI exits. An independently running collector is never killed or duplicated.
- Existing read-only NVIDIA, WMI, CPU/RAM, 3ds Max, Windows Event and Evidence engines are retained. NVIDIA SMI standard Windows folders are checked if PATH does not contain it.
- Built-in on-demand Evidence capture with selected sources and explicit RAW log consent, Open Logs Folder and Evidence Folder.
- Live ComfyUI node and progress when localhost WebSocket reports them; a normalized local event list without prompts, prompt text or images. No invented ETA.
- Background release-version metadata check only; unsigned automatic installation remains disabled.

## GPU processes — read-only WDDM snapshot (v0.9 candidate)
- Fifth tab **GPU-процессы / GPU processes**; a read-only sortable list displays application short name, PID, dedicated (VRAM) and shared GPU memory in MiB.
- Source: **Windows WDDM GPU Process Memory performance counters**, via `Win32_PerfRawData_GPUPerformanceCounters_GPUProcessMemory` (CIM). NVIDIA documents that `nvidia-smi` per-process memory is unavailable under WDDM; do not treat its `N/A` as zero.
- Polling is asynchronous and only occurs while the GPU-process tab is selected, approximately every 5 seconds. It does not block the main WPF UI, run a stress test, terminate processes or write process information to logs.
- Aggregates multiple GPU memory counter instances by PID. Values reflect Windows per-process allocations; they may include multiple adapters and **must not be summed or compared one-to-one** to NVIDIA board total.
- Missing/unavailable counters or insufficient permissions show **UNAVAILABLE / N/A**, never a fabricated 0 MiB. Only executable short names are displayed; no paths, command lines or client content.
- Read-only tests cover PID grouping and neutral fallback; actual WDDM measurements on HOME/WORK require manual comparison to Windows Task Manager before claiming production correctness.

## Not yet supported
- Prompt/result gallery and detailed workflow configuration from ComfyUI are **not yet implemented**; the Generations pane explicitly states that normalized event data are all that is displayed.
- Free VRAM/RAM cache action is **not implemented**: no tested safe semantics for active generations and existing HOME GPU TDR incidents.
- System-tray and compact HUD are still supported by older source but not integrated into unified WPF view. One-window launch is intentional.
- No Windows 95 WinForms Dashboard or standalone Configurator appears on the v0.9 normal launch path. Legacy scripts stay for backwards-compatibility validation.

## Test matrix / acceptance

1. Windows PowerShell 5.1 parse of unified app, Collector, installer; WPF XAML loader; 4 tabs and RU/EN; main installation and data-preserving uninstall.
2. Windows CI builds unsigned per-user Inno EXE and portable BAT/ZIP, smoke installs with selected profile; full previous v0.8 regression remains green.
3. Real HOME and WORK: one window only, no visible console; no duplicate Collector; GPU/VRAM/CPU/RAM present where supported; 3ds Max running/not running; Russian selected; language persisted after restart; Logs and Evidence buttons work.
4. With ComfyUI offline: WPF opens, does not block, no fabricated node progress. With ComfyUI online: node changes/progress match WebSocket, no prompts leaked.
5. Reopen after a crash, verify Windows evidence available from explicit snapshot and data preserved.

**STOP** if any extra console opens, collector duplicate writers appear, GPU driver instability repeats, WPF layout clips at DPI 100/125/150, release updater attempts unsigned silent execution, or Evidence exports raw contents without consent.

**Rollback:** Previous v0.8.0-LAB Release: https://github.com/lutiy-dev/ComfyUI-Diagnostics-Monitor/releases/tag/v0.8.0-LAB . Close app before reinstalling; preserve local `%LOCALAPPDATA%\ComfyUI-Diagnostics` data. Do not merge/ship as PRODUCTION until real Windows HOME/WORK runtime verification.
