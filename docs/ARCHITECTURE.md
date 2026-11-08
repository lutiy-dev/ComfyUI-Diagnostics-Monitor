# Diagnostics architecture — DRAFT v0.1

**State:** PROPOSED, not implemented or tested on Windows.

## Mission
One lightweight Windows dashboard for ComfyUI sessions and GPU stability. Support HOME (3070 Ti) and WORK (4090), with all captured data private by default.

## Components
1. **NVIDIA collector**: poll `nvidia-smi` at a configurable interval for GPU utilization, VRAM allocated/used, temperature, board power, and detected process information where supported. Missing metrics are unknown, not zero.
2. **Windows collector**: read selected Event Log records (Display 4101, WHEA-Logger, Kernel-Power 41, LiveKernelEvent reports where available). Event 41 records unclean shutdown; it does not identify the original cause.
3. **ComfyUI collector**: tail configured ComfyUI log files; optionally subscribe to localhost WebSocket and HTTP queue/history endpoints for active node, sampler step, job/queue state. WebSocket progress is not guaranteed for every node.
4. **Correlator**: retain source event IDs, normalize timestamps and group nearby faults without claiming causal certainty.
5. **Local store**: append-only raw JSONL with rotation and a SQLite summary/index; backups and retention configurable.
6. **Dashboard**: current health, history graphs, session timeline, filters by HOME/WORK, and export of sanitized incident bundles.

## Storage / transfer
- By default no external communication, cloud sync, or automatic incident upload.
- GitHub contains source code and publicly safe example fixtures, never actual machine telemetry.
- Cross-machine aggregation is a later opt-in project requiring documented transport, authentication, encryption, redaction and rollback. No shared backend yet.

## Example event contract (illustrative, not schema-final)
```json
{
  "schema_version": 1,
  "machine_alias": "HOME",
  "source": "Windows",
  "kind": "Display",
  "code": "4101",
  "severity": "error",
  "time_utc": "2026-11-08T16:35:22Z",
  "message_redacted": "Display driver stopped responding and recovered"
}
```

## First incident reference (user-supplied evidence)
- HOME: RTX 3070 Ti 8 GB; Windows 10 build 19045; NVIDIA driver 616.92.
- 2026-11-08 ~19:35 local: Windows Display 4101 and LiveKernelEvent 141.
- ComfyUI 0.42.1, PyTorch 2.10.0+cu130, comfy-aimdo 0.5.6, comfy-kitchen 0.2.39.
- Failure surfaced in MiniMax H3 sampler / CUDA INT8 linear; cleanup showed aimdo memory compile error. Exact root cause NOT CONFIRMED.
- A test launch with `--disable-comfy-compiler` started successfully; full-generation stability NOT TESTED.
- No raw logs or local paths should be committed to GitHub.

## Release gates
GENERATED → VALIDATED (source and tests) → TESTED (Windows HOME/WORK) → RELEASE CANDIDATE → PRODUCTION only after repeatable checks.
