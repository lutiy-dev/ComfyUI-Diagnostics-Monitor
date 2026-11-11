# CPU / RAM / 3ds Max Monitoring — LAB Candidate

**Baseline:** Draft PR #15 `958678aa8cadda6dd2bca4a7d6255761281c7433` (Dashboard/HUD UI pass).  
**Scope:** Optional additive telemetry and Dashboard display; NOT PRODUCTION.

## Source-of-truth / values

- System CPU: `Get-CimInstance Win32_Processor` LoadPercentage averaged across reported processors; **approximate Windows/WMI value**, not a low-latency high-precision sensor. `cpu={status:'OK', util_pct:<percent>}` or `status:'UNAVAILABLE'` (safe read-only fallback).
- System RAM: existing `ram.used_mib`/`ram.total_mib` from `Win32_OperatingSystem`, unchanged. Dashboard converts MiB to GiB and plots used/total as % when available.
- 3ds Max: aggregate resident working-set and private bytes from all running `3dsmax.exe` instances, `max_memory={status:'OK',count,working_set_mib,private_mib}`, `NOT_RUNNING` or `UNAVAILABLE`. **Not a Corona engine-specific breakdown**: Corona works inside 3ds Max process. No process commands, paths, prompts, workflow names, command lines or PIDs recorded.
- Dashboard: new CPU/RAM colored chart series, text metrics for CPU / RAM / 3ds Max. Existing GPU/VRAM colors, series names, HUD GPU/VRAM display and JSONL schema=1 preserved.
- In old JSONL files with no new fields, Dashboard shows `--` / `NO DATA` instead of creating fake values.

## Boundaries

- Existing 5-second collector interval unchanged. WMI CPU query can add polling overhead; monitor real runtime before accepting as production. This is **not** a performance profiler.
- No GPU reset, empty cache, unload-model, driver change, Windows registry modification, stress testing, autostart, or second Collector instance.
- Read-only and local-only. Old JSONL records remain compatible. No raw application internals recorded.

## Acceptance & STOP

1. Windows PowerShell parse, existing HUD/WinForms/WebSocket/Evidence/installer CI PASS at exact branch head.
2. Real HOME and WORK: CPU percent non-null, RAM current used/total matches rough Task Manager readings, and 3dsmax.exe state NOT_RUNNING when absent / OK when running. No action invoked on 3ds Max or its scenes.
3. Graph retains GPU/VRAM history and adds CPU/RAM where available; verify at 100/125/150% Windows scaling and with Collector STALE.
4. No noticeable lag/freeze introduced by WMI. **STOP** on GPU/Windows instability; in particular HOME has confirmed TDR/LiveKernelEvent 141, so no stress tests or benchmark to validate this feature.

Rollback: previous PR #15 Windows ZIP. Diagnostics data directory remains separate. Never merge/ship without approval.
