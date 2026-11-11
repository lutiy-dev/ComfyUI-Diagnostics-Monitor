# Live Windows Dashboard · LAB v0.4

**Status:** source GENERATED. WinForms runtime on HOME/WORK is **NOT TESTED** until on-device verification. No release is available.

## Scope
One read-only Windows dashboard for live ComfyUI progress events and historical GPU data already recorded by the v0.3 collector. It does not start/stop ComfyUI, submit jobs, change models, modify driver settings, or communicate with remote hosts.

- **WebSocket:** local `/ws?clientId=<uuid>`; handles `executing`, `execution_start`, `progress`, `execution_error`, `execution_success`, `execution_interrupted`, `status`. ComfyUI versions may differ; active node ID is available only when sent by server. There is no guarantee of step progress for every sampler.
- **Collector:** unchanged v0.3 `collector.ps1` captures GPU/VRAM/temp/power/RAM, Windows event IDs, queue and log signature. Run it separately.
- **Dashboard:** latest sample, stale indication after 20 seconds, GPU% and VRAM% history (up to 120 recent samples), live node ID and progress bar, normalized incident timeline.
- **Storage:** local JSONL files under `%LOCALAPPDATA%\ComfyUI-Diagnostics`. Live WS event logs capped at 5 MiB per machine/day, existing v0.3 collector has rollover without global retention. No raw prompts or exception messages are saved.
- **Private:** never commit captured `*.jsonl`, SQLite DB or logs. No auto sync / network upload. GitHub contains only source and tests.

## Home test: Windows PowerShell 5.1
Start ComfyUI separately with your usual safe settings. Do **not** start a heavy generation for initial UI test. In repo folder, open separate PowerShell windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\collector.ps1 -Machine HOME -ComfyLog "Q:\AI_ArchViz\ComfyUI_windows_portable\ComfyUI\user\comfyui.log"
```
```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\dashboard.ps1 -Machine HOME
```

Run WORK with `-Machine WORK` and that computer's actual `-ComfyLog` path. Same source, separate local data. The dashboard connects to `http://127.0.0.1:8188` by default. It can be started without ComfyUI; WebSocket status should show disconnected until the server starts.

## Acceptance criteria
1. **PASS**: both scripts parse in Windows PowerShell 5.1; normalization tests pass on Windows CI.
2. **PASS**: HOME actual UI opens without unhandled exceptions; when collector running, GPU/VRAM/temp/power refresh and history chart appears; when collector stops, data becomes STALE.
3. **PASS**: ComfyUI localhost connection changes to CONNECTED; an explicitly authorized safe test emits node and step progress, when supported; error event is sanitized.
4. **PASS**: local `live_HOME_*.jsonl` stores normalized codes/IDs, no prompts, tokens or client data.
5. **STOP**: GPU/Display instability, unexpectedly high CPU/disk use, missing permissions, arbitrary path exposure, or any remote connection.

## Known limitations
- Dashboard uses System.Windows.Forms and is Windows-only.
- Real Windows UI and high-load tests are NOT TESTED in CI; CI only parses code and tests event normalization.
- Live progress is not replayed if dashboard starts after a job is already running; wait for the next event.
- Event correlation is temporal, not causal. No root-cause AI inference or shared cross-machine database yet.
- No automated cleanup of historical files; supervise collection and archive privately.
- Closing the dashboard disconnects only its WebSocket and does not stop the collector.
- If the collector crashes, historical values can remain visible but flagged STALE.
