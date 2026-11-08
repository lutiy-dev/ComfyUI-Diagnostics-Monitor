# ComfyUI Diagnostics Monitor

**v0.6.0-LAB candidate · Windows 10/11 · READ-ONLY · LOCAL-FIRST · NOT PRODUCTION**

A Windows diagnostic monitor and on-demand evidence recorder for NVIDIA/ComfyUI. Intended for investigating CUDA errors, GPU driver timeouts, application crashes and performance regressions without changing models, workflows, drivers or Windows settings.

## Capabilities

- **Collector** (`collector.ps1`): existing continuously polled GPU/VRAM/temp/power, RAM, ComfyUI queue/log signatures, selected Windows events, JSONL.
- **Dashboard / HUD** (`dashboard.ps1`): interactive Windows Forms GPU history, incident timeline, always-on-top fullscreen/compact overlay; status of ComfyUI WebSocket if available.
- **Configurator** (`configurator.ps1`): choose evidence sources and time window; capture locally **only when requested**.
- **Evidence** (`evidence.ps1`): normalized System/Application Events, Reliability Records, NVIDIA, CPU, memory, storage, Python candidate processes, ComfyUI startup version signatures and queue/log diagnostics. Uses local timestamps and source status; does not copy prompts or event text.
- **Offline analysis** (`analyze_evidence.py`): classify observable signals, missing sources and compare two environment snapshots without claiming proof of a root cause.
- **Installer** (`install.ps1`): non-admin PowerShell LAB ZIP; HOME/WORK aliases; separate data storage; uninstaller preserves local evidence and logs.
- **GitHub Actions**: Windows parser/GUI initialization/HUD transitions, installer/uninstall/data preservation, offline unit tests and SHA256/inventory security gate.

## Install

Download the **CI artifact** from the latest validated PR run; verify checksum, Defender and Chrome verdict before installing. This is an **unsigned PowerShell LAB ZIP**, not an EXE/MSI or Production Release.

```powershell
.\install.ps1 -Machine HOME -ComfyLog "Q:\AI_ArchViz\ComfyUI_windows_portable\ComfyUI\user\comfyui.log"
```
Existing installation: stop GUI/collector, ensure local backups, then add `-Upgrade` to explicitly replace installed code. For WORK substitute `-Machine WORK` and the actual WORK log path.

Installed program: `%LOCALAPPDATA%\Programs\ComfyUI-Diagnostics`.

Private data: `%LOCALAPPDATA%\ComfyUI-Diagnostics`. The installer and uninstaller do not remove this data.

Start Menu: **ComfyUI Diagnostics LAB** → Dashboard / Collector / Configurator. The collector only records when explicitly started; open the Configurator to create a diagnostic snapshot after a failure. No automatic cloud upload, service, scheduled task, driver change or ComfyUI mutation.

## For ChatGPT Work

Open/authorize the local diagnostic data folder when you want an investigation. Request a read-only inspection of `evidence\*.json` and existing HOME/WORK JSONL, with specific time window. Treat the observed signals and cause hypotheses separately. Nothing is uploaded to public GitHub. Folder access is user-controlled and only when supported by ChatGPT Work.

## Documentation

- [Diagnostics v0.6 & scenario coverage](docs/DIAGNOSTICS_V06.md)
- [Windows setup](docs/WINDOWS_INSTALL.md)
- [HUD mode](docs/HUD_MODE.md)
- [Security review](docs/PACKAGE_SECURITY.md)
- [ChatGPT file access](docs/CHATGPT_DIAGNOSTICS_ACCESS.md)
- [Architecture specification](docs/DIAGNOSTICS_CONTROL_CENTER_SPEC.md)

## Scope and limitations

No guaranteed diagnosis for hardware freezes. WinForms integration and HOME/WORK target runtime must be verified on both computers before PRODUCTION. Existing v0.3 continuous collector lacks global retention. Extra sensors (CPU temperature, per-node execution progress, full traceback, WER dumps) are not automatically collected. GPU/CPU/WMI availability varies. No signed updates or automatic fixes; in-app update button only checks official release metadata on explicit user action.

**Workflow:** INSPECT → CAPTURE → SOURCE-CHECK → CORRELATE → TEST ONE VARIABLE → PASS/FAIL → DOCUMENT. Retain evidence of unsuccessful tests. No automated registry TDR tweaks, system repairs, NVIDIA driver changes or forced stress tests.

## Development

```powershell
python -m unittest discover -s tests -v
.\configurator.ps1 -SelfTest
.\evidence.ps1 -Machine HOME -DataRoot "$env:TEMP\ComfyUIDiagnosticsTest" -SkipWindows -SkipProcesses -SkipStorage -SkipComfy -SelfTest
```

Contributions should follow [AGENTS.md](AGENTS.md). Draft PRs remain separate; no main/release changes without review.
