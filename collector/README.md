# Local collector v0.3 (LAB)

Read-only PowerShell collector for HOME/WORK NVIDIA Windows machines.
No automatic background service, external telemetry upload, shared database, or changes to ComfyUI.

## Run locally
Requires Windows PowerShell 5.1. No mandatory Python package or admin permission.
Open PowerShell in repository root and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\collector.ps1 -Machine HOME -ComfyLog "Q:\AI_ArchViz\ComfyUI_windows_portable\ComfyUI\user\comfyui.log"
```

For WORK, select `-Machine WORK` and provide that machine's actual ComfyUI log path.
To skip ComfyUI log parsing, omit `-ComfyLog`.
The ComfyUI API endpoint must remain local, e.g. `http://127.0.0.1:8188`.

Logs and events are stored under `%LOCALAPPDATA%\ComfyUI-Diagnostics`.
Raw JSONL and SQLite files must never be committed or published.
Press Ctrl+C to stop. Preserve working ComfyUI/driver configuration.

## Import offline

```powershell
python .\merge_to_sqlite.py --db .\diagnostics.sqlite ".\private-logs\*.jsonl"
python -m unittest discover -s tests -v
```

Repeated imports of identical records are deduplicated.

## Known limitations

- Windows PowerShell runtime and NVIDIA GPU tests: NOT TESTED in CI.
- No current node or step WebSocket integration yet.
- Recent log signature can be historical, not a new error.
- Windows System event cursor reduces duplicate imports; if the event log is cleared, remove local cursor after inspection.
- Each JSONL file gets a size rollover, **but total storage has no retention limit**.
- Windows Event Log polling reads up to 24 hours of system entries every 60 seconds; watch resource use.
- GPU metrics unavailable on some drivers may appear as `N/A`.
- LiveKernelEvent 141 from Reliability Monitor is not yet collected.
- A GPU crash can prevent records being flushed; use recorded timestamps as evidence, not guarantees.

Status: GENERATED / Python tests pending at GitHub commit; Windows runtime NOT TESTED.
