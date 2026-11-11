# ComfyUI Diagnostics & System Control Center — Specification v0.1

**Status:** DESIGN / NOT IMPLEMENTED. Based on HOME v0.3 collector and v0.4 WinForms dashboard. Existing PR #1 → #2 → #3 remain separate and unmerged.

## Product objective

A private, local-first Windows diagnostic system for ComfyUI workflows. Record sufficient evidence to correlate failures across ComfyUI, NVIDIA, CPU, RAM, storage, Windows, without guessing the root cause. Support HOME (RTX 3070 Ti 8 GB) and WORK (RTX 4090 24 GB) with per-machine profiles.

**Not a privileged automated repair engine.** Observation is read-only. Configuration proposals need explicit user approval, backup, risk, and rollback. Never force GPU stress or change ComfyUI models / workflows / drivers on its own.

## Diagnostic data sources

| Layer | Default inexpensive signals | On-demand deep capture |
| --- | --- | --- |
| NVIDIA GPU | driver version; GPU util; VRAM used/total; temperature; board power; device health and optional clocks/fans where supported by nvidia-smi | GPU device/driver errors; signed driver metadata; fault-specific trace if available |
| CPU | load per core and total; process CPU; clock/temperature only if supported by validated provider | CPU throttling / WHEA processor events / selected performance counters |
| RAM and page file | physical available/used; commit and page-file pressure; ComfyUI process working set | application-specific allocations / memory dump only after explicit opt-in |
| Storage | free space, I/O read/write throughput, queue latency; disk-related system events | SMART/drive health via documented Windows APIs, if supported; no arbitrary raw disks |
| Windows | System + Application Event Log filtered for critical/error/warning providers: Display 4101, WHEA, Kernel-Power, disk/storport, Application Error, Windows Error Reporting; Reliability Monitor codes when available | selected exported EVTX/WER reports with user preview and redaction; ETW only for a bounded explicitly started incident session |
| ComfyUI | server availability, queue, history status, normalized error signatures, process/session version, logs with timestamps and offsets | active node and progress with a documented safe event integration; optional sanitized workflow fingerprint (NOT full workflow/prompts) |
| Runtime | Python / PyTorch / CUDA driver API / ComfyUI / custom node version manifest | environment compatibility diff against a successful baseline |

**Unknown/unsupported is not zero.** No unverified CPU temperature claims; NVIDIA sensor support varies.

## Configurator modules

1. **Profiles:** HOME, WORK; configurable ComfyUI base URL (localhost only), user-provided log path, machine alias; no user name or absolute local path in shared profiles.
2. **Sources:** enable/disable data sources with UI preview of what is collected. Read-only, least privilege, and permissions errors shown visibly.
3. **Sampling:** default GPU 5 seconds; CPU/RAM 5 seconds; queues 5 seconds; Windows events incremental at 30-60 seconds; avoid full 24-hour Event Log queries on every cycle.
4. **Storage:** per-day JSONL segments and SQLite index; no duplicated events, rotation; total disk quota and retention time, with user-visible archive-before-delete and protected current incident.
5. **Incident mode:** bounded higher-frequency capture started manually or by explicit configured trigger (e.g., WHEA, Display 4101, ComfyUI exception); capture pre/post-event samples in a ring buffer where technically possible.
6. **Privacy:** on-device by default; export always opt-in with preview, source/path/token/prompt redaction; no automatic GitHub Issue, cloud sync, screenshot, full prompts, binary dumps, or shell command-line collection.
7. **Recovery suggestions:** distinguish CONFIRMED signal, HYPOTHESIS, proposed test, risk, rollback; no automated driver/TDR registry changes, model swaps, workflow edits, or process terminations.
8. **Dashboard:** tabs Live, Sessions, Incidents, Logs, Environment, Settings; show source freshness and missing metrics; time axis always explicitly UTC and local zone.
9. **Reproducible comparison:** compare failed session against baseline with same model, quantization, driver, ComfyUI, seed, steps, dimensions, GPU; report changes separately from observed error.
10. **Multi-machine:** local independent databases for HOME and WORK. Future optional encrypted private sync requires new approval and threat model.

## Incident data model

- `machines`: anonymous alias and non-sensitive hardware metadata
- `sessions`: start/stop UTC, workflow fingerprint (opt-in), environment fingerprint, status
- `samples`: timestamp UTC, source, metric, value, unit, availability
- `events`: timestamp UTC, provider, event ID/code, machine alias, normalized severity, source sequence / record ID, safe detail
- `incidents`: window UTC start/end, linked event IDs, classification status, diagnostic note and proposed validation
- `changes`: only user-approved configuration changes and reversible checkpoint evidence

Keep original time and source; do not deduce causal relationships just because two errors are nearby. Use SQLite primary keys for stable event deduplication and indexes for machine/time/source.

## First incident regression fixture (synthetic/anonymized)

The 2026-11-08 HOME failure evidence: MiniMax H3 sampler, Windows Display event 4101, LiveKernelEvent 141, subsequent CUDA unknown error and aimdo cleanup exception. No statement that aimdo, VRAM shortage, overheating or NVIDIA driver alone is the root cause. Do not commit full user logs.

## Acceptance gates

### M1 — collector hardening
- Functional incrementally polled Windows logs, bounded disk retention, WER discovery and metrics availability.
- Tests for 2 machines, restarts, event deduplication, date transitions, Windows path Unicode, missing GPU, API offline, event log permission denial, partial JSONL, stale data.
- Fail-safe: no automatic changes to Windows/ComfyUI and no external telemetry.

### M2 — ComfyUI progress
- Identify session & node through a real ComfyUI-safe mechanism; don't hijack browser clientId.
- Show sampler step only if confirmed from real emitted event; no fabricated progress.
- Test lightweight workflow on HOME with old collector as baseline.

### M3 — Configurator & UI
- Settings validation, source freshness, stop/start capture, retention controls, searchable incident history, optional CSV/JSON export with preview.
- Test reboot, no ComfyUI, multiple GPUs, no admin, 3070 Ti and 4090.

### M4 — installer/release
- Signed or inspectable scripts/installer, checksum, versioned GitHub Release and portable path; install/upgrade rollback and audit.
- Windows runtime tests on HOME and WORK; no PRODUCTION label from CI alone.

## Explicit STOP

GPU TDR, display loss, high CPU/disk use from collector, missing permissions, unbounded logs, sensitive data in export, unexpected outbound traffic, cross-machine path leakage, or unapproved runtime modification. Stop the test, preserve current evidence, classify NOT TESTED/FAIL.

## Proposed implementation order

Existing baseline → read-only source configuration schema and safety limits → collector reliability/retention → incident database and WER/Windows sources → safe node progress → settings UI and incident browser → HOME/WORK testing → release. This specification alone changes no runtime or published release.
