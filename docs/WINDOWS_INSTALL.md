# Windows LAB Installer v0.5 — non-admin ZIP package

**Status:** LAB candidate; no EXE/MSI yet. This is a user-level PowerShell installer inside a versioned ZIP, not a production signed installer.

## What it creates

- App: `%LOCALAPPDATA%\Programs\ComfyUI-Diagnostics`
- Private data: `%LOCALAPPDATA%\ComfyUI-Diagnostics` (existing v0.3 HOME data reused, never deleted)
- Optional Start Menu shortcuts: `ComfyUI Diagnostics LAB\Dashboard` and `Collector`
- Program manifest/config: `installation.json`, `config.json`; machine HOME/WORK and ComfyUI log path configured locally.

It does not install Python, change drivers, alter ComfyUI, start a Windows service, schedule monitoring, add firewall rules, upload data or change registry TDR. Requires Windows PowerShell 5.1, Windows Forms/.NET, NVIDIA SMI for GPU metrics.

## Install on HOME

From the extracted ZIP directory containing `install.ps1`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Machine HOME -ComfyLog "Q:\AI_ArchViz\ComfyUI_windows_portable\ComfyUI\user\comfyui.log"
```

The installer refuses overwrite except with explicit `-Upgrade`. Program files are copied into the app folder. The old local diagnostic folder is preserved.

For WORK use `-Machine WORK` and that machine's known ComfyUI log path; don't invent its path.

## Start

Start Menu → ComfyUI Diagnostics LAB → Collector (when you want recording), then Dashboard. The collector is a blocking process; stop with Ctrl+C. The dashboard also works without collector but displays historical STALE data.

The collector has to be running to record **new GPU/VRAM samples**. Events Windows already captured may later be queried even if collector was off. ComfyUI's own log is written by ComfyUI, not by this installer. Current collector logs are normalized, not a full transcript of all errors. Therefore this is NOT YET a complete diagnostic forensic archive.

## Share with ChatGPT

The local folder is private Windows data; opening a folder via `Open project in ChatGPT` needs a real access test before claiming ChatGPT can read every file or monitor changes. Without verified access, select a small, reviewed log/export and attach it manually to a chat. **Do not upload private logs to the public GitHub repository.**

The later opt-in incident exporter must redact secrets, private client file paths and prompts, and will only copy chosen time windows. Folder access cannot be guaranteed by this installer.

## Uninstall

Stop running collector and dashboard, then:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Uninstall removes only known installed program files and its own shortcuts, **not** diagnostic data. Backups are optional: existing data should be backed up before destructive manual operations. If a custom InstallRoot was used, pass the same `-InstallRoot` to uninstall.

## Tests and limitations

Windows CI:
- PowerShell syntax of installer, dashboard, collector and HUD;
- install into isolated temporary folder;
- WinForms initialization smoke test;
- uninstall and assert diagnostic data preservation;
- ZIP + SHA-256 uploaded as CI artifacts.

Real HOME GPU and UI, Start Menu shortcuts, installation while previous collector is running, Unicode custom paths, Windows Defender reputation, and WORK hardware are **NOT TESTED** until manually checked. No signed EXE/MSI, auto-update, background service, or automatic repair is supplied. **Do not install into a folder containing user files.**

STOP for accidental data deletion, incorrect path, conflicts with running programs or Windows security warnings. No forced restart or driver changes.
