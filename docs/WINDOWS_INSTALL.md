# Windows Installer — v0.8 LAB CANDIDATE

**Status:** unsigned per-user GUI EXE + inspectable BAT/PowerShell fallback. NOT PRODUCTION.

## Supported platforms
Windows 10/11 x64; Windows PowerShell 5.1, .NET WinForms. NVIDIA SMI is optional but required for GPU metrics. No administrator privileges.

## Choose one install method

**Recommended:** run `ComfyUI-Diagnostics-Setup-v0.8-LAB.exe` by double click. Select HOME (RTX 3070 Ti) or WORK (RTX 4090) in the wizard. The EXE is compiled from the auditable `tools/windows-setup.iss` by the Windows CI job and delegates installation to the repository's `install.ps1`. It is **unsigned**; validate GitHub origin, SHA256 and Windows security verdict before running.

**Fallback:** extract `ComfyUI-Diagnostics-LAB-v0.8.zip`. Open the *inner* `ComfyUI-Diagnostics-LAB` folder and double click `Install-or-Update.bat`; select HOME or WORK. It asks for confirmation, then invokes the existing PowerShell installer with `-Upgrade`. Do not launch the BAT from an untrusted directory.

**Manual CLI** (troubleshooting only):

```powershell
.\install.ps1 -Machine HOME -Upgrade
```

## Updating without losing evidence

Close Dashboard, Configurator and Collector before running either installer. The installed program is updated in `%LOCALAPPDATA%\Programs\ComfyUI-Diagnostics`. Diagnostic JSON and JSONL remain in `%LOCALAPPDATA%\ComfyUI-Diagnostics` and are preserved by upgrades and the provided uninstaller. Existing ComfyUI log configuration is retained unless explicitly overridden. Current v0.8 installer is not transactional; keep the previous validated ZIP/EXE as the rollback point and re-run it if a new setup fails. **Do not upgrade during an active capture or a 3ds Max render being diagnosed.**

Start Menu: `ComfyUI Diagnostics LAB` → Dashboard, Collector, Configurator. No auto-start, Windows service, forced process kill, GPU reset, registry adjustment or driver change.

## Logs and reporting

Use **Open Logs Folder** in Dashboard or Configurator to open `%LOCALAPPDATA%\ComfyUI-Diagnostics`. `evidence\` contains manually generated JSON. `telemetry_HOME_*.jsonl`, `events_HOME_*.jsonl` and `live_HOME_*.jsonl` (or WORK aliases) record samples and events while their respective sources are running.

No files are uploaded automatically; inspect and redact filenames, paths and client context before sharing.

## Update safety

The Dashboard checks metadata from the official GitHub releases API automatically once per app launch, without downloading or installing programs. If a newer published version is found, the update button changes to **Update available**. Clicking it opens the official release page only after confirmation. Automatic install is disabled pending Authenticode signing, robust code rollback and running Collector shutdown. Hashes in release assets provide integrity, not publisher authenticity.

## CI acceptance and STOP

The Windows Actions workflow must pass: PowerShell source parsing; WinForms/HUD/Evidence tests; ZIP SHA256/allowlist; non-admin install and uninstall data retention; Inno Setup compilation; EXE silent-install smoke and data preservation. Actual HOME/WORK Defender/SmartScreen reputation and long-running multi-hour Collector validation are still required.

STOP on any unexpected security warning, unknown publisher behavior, failing checksum, missing installed shortcut, overwritten diagnostic data, installation into a directory with unmanaged user files, or an attempted unsigned unattended update.
