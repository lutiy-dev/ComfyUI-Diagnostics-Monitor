# ComfyUI Diagnostics Monitor

**v0.7.0 · VERIFIED LAB CANDIDATE · Windows 10/11 · LOCAL-FIRST · READ-ONLY · NOT PRODUCTION**

**Evidence (2026-11-10):** Windows CI 3/3 PASS on the previous code commit; WORK RTX 4090 install, Dashboard, offline/online Evidence, ComfyUI `/system_stats` and shared-log SHA-256 passed real-host checks. Final HOME check of the latest patch and continuous Collector durability remain open. [Test matrix and limitations](docs/DIAGNOSTICS_V07.md). Do not confuse a validated candidate with a stable release.

A Windows diagnostic monitor and on-demand evidence recorder for NVIDIA/ComfyUI. Intended for investigating CUDA errors, GPU driver timeouts, application crashes and performance regressions without changing models, workflows, drivers or Windows settings.

## Capabilities

- **Collector** (`collector.ps1`): existing continuously polled GPU/VRAM/temp/power, RAM, ComfyUI queue/log signatures, selected Windows events, JSONL.
- **Dashboard / HUD** (`dashboard.ps1`): interactive Windows Forms GPU history, incident timeline, always-on-top fullscreen/compact overlay; status of ComfyUI WebSocket if available.
- **Configurator** (`configurator.ps1`): choose evidence sources and time window; capture locally **only when requested**.
- **Evidence** (`evidence.ps1`): normalized System/Application Events, Reliability Records, NVIDIA, CPU, memory, storage, Python candidate processes and ComfyUI queue/log diagnostics. Uses localhost `/system_stats` for running ComfyUI/Python/PyTorch versions (log fallback), and best-effort shared-read SHA-256 of active logs. Explicit per-source OK/EMPTY/PARTIAL/UNAVAILABLE status; no prompts or raw event messages in the regular JSON.
- **Offline analysis** (`analyze_evidence.py`): classify observable signals, missing sources and compare two environment snapshots without claiming proof of a root cause.
- **Installer** (`install.ps1`): non-admin PowerShell LAB ZIP; HOME/WORK aliases; separate data storage; uninstaller preserves local evidence and logs.
- **GitHub Actions**: Windows parser/GUI initialization/HUD transitions, installer/uninstall/data preservation, offline unit tests and SHA256/inventory security gate.

## Install

Download the **Windows CI artifact** attached to [Draft PR #12](https://github.com/lutiy-dev/ComfyUI-Diagnostics-Monitor/pull/12), verify its exact workflow head/manifest and scan the ZIP before opening. The package is an **unsigned PowerShell LAB ZIP**, not an EXE/MSI or a Production Release.

Run PowerShell in the extracted inner `ComfyUI-Diagnostics-LAB` directory:

```powershell
.\install.ps1 -Machine WORK
# HOME uses -Machine HOME; supply -ComfyLog only after verifying its exact path.
```

Prefer a no-install, isolated evidence run for first acceptance:

```powershell
.\evidence.ps1 -Machine WORK -DataRoot "$env:TEMP\ComfyUIDiagnosticsV07Test" -ComfyUrl "http://127.0.0.1:8188" -Hours 3
```

The local ComfyUI port may differ. Missing/closed ComfyUI is reported as unavailable, not repaired or auto-started.
Existing installation: stop GUI/collector, ensure local backups, then add `-Upgrade` to explicitly replace installed code. For WORK substitute `-Machine WORK` and the actual WORK log path.

Installed program: `%LOCALAPPDATA%\Programs\ComfyUI-Diagnostics`.

Private data: `%LOCALAPPDATA%\ComfyUI-Diagnostics`. The installer and uninstaller do not remove this data.

Start Menu: **ComfyUI Diagnostics LAB** → Dashboard / Collector / Configurator. The collector only records when explicitly started; open the Configurator to create a diagnostic snapshot after a failure. No automatic cloud upload, service, scheduled task, driver change or ComfyUI mutation.

## For ChatGPT Work

Open/authorize the local diagnostic data folder when you want an investigation. Request a read-only inspection of `evidence\*.json` and existing HOME/WORK JSONL, with specific time window. Treat the observed signals and cause hypotheses separately. Nothing is uploaded to public GitHub. Folder access is user-controlled and only when supported by ChatGPT Work.

## Documentation

- [Evidence Reliability v0.7 — scope, tests and limitations](docs/DIAGNOSTICS_V07.md)
- [Diagnostics v0.6 & scenario coverage](docs/DIAGNOSTICS_V06.md)
- [Windows setup](docs/WINDOWS_INSTALL.md)
- [HUD mode](docs/HUD_MODE.md)
- [Security review](docs/PACKAGE_SECURITY.md)
- [ChatGPT file access](docs/CHATGPT_DIAGNOSTICS_ACCESS.md)
- [Architecture specification](docs/DIAGNOSTICS_CONTROL_CENTER_SPEC.md)

## Scope and limitations

No guaranteed diagnosis for hardware freezes. Real WORK smoke and online Evidence have passed; the latest patch is not yet fully verified on HOME and multi-hour Collector / sleep-resume / rotation reliability remains untested before PRODUCTION. Existing v0.3 continuous collector lacks global retention. Extra sensors (CPU temperature, per-node execution progress, full traceback, WER dumps) are not automatically collected. GPU/CPU/WMI availability varies. No signed updates or automatic fixes; in-app update button only checks official release metadata on explicit user action.

**Workflow:** INSPECT → CAPTURE → SOURCE-CHECK → CORRELATE → TEST ONE VARIABLE → PASS/FAIL → DOCUMENT. Retain evidence of unsuccessful tests. No automated registry TDR tweaks, system repairs, NVIDIA driver changes or forced stress tests.

## Development

```powershell
python -m unittest discover -s tests -v
.\configurator.ps1 -SelfTest
.\evidence.ps1 -Machine HOME -DataRoot "$env:TEMP\ComfyUIDiagnosticsTest" -SkipWindows -SkipProcesses -SkipStorage -SkipComfy -SelfTest
```

Contributions should follow [AGENTS.md](AGENTS.md). Draft PRs remain separate; no main/release changes without review.
