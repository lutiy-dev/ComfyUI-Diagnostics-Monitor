# Evidence Reliability v0.7 — LAB CANDIDATE

**Status:** Windows CI candidate. Not a Production Standard or HOME/WORK hardware acceptance.

**Baseline:** HOME-tested v0.6 `f52bc0e9f8d177a421dbd5f7e337e1ee309c44ac` (Draft PR #11).
**Branch:** `fix/evidence-reliability-v07-20261109` (Draft PR #12).
**Rollback:** retain original v0.6 installer ZIP and installed HOME data; do not merge/install automatically.

## Change scope

- Preserve `schema: 2`, `sources`, existing measurement field names and output location.
- Each sampled source now records a local-free UTC sampling completion timestamp and duration, except deliberately disabled sources.
- `OK`: source has non-empty values. `EMPTY`: legitimate zero-event result. `PARTIAL`: incomplete evidence such as unknown environment version or unavailable full-log hash. `UNAVAILABLE`: collection failure with sanitized error code. `DISABLED`: user excluded source.
- `coverage.available` includes only full `OK`; `coverage.empty` and `coverage.partial` are reported separately and also included in `missing` for compatibility with existing consumers.
- Windows events use provider filters **in the query** before the 350-event bound; System and Application include levels 1–4 because WER may write informational events. Only provider/code/time/record_id/level are persisted; Windows event messages and paths are excluded.
- Reliability records return `EMPTY` rather than `OK: {}` when no records are found.
- ComfyUI log signature scan opens the file with `FileShare.ReadWrite` and reads at most the last 1 MiB and 1500 lines. Whole-file SHA-256 uses an independent shared-read stream; it is marked `STABLE_BEST_EFFORT` only if file length and modification time remain unchanged before/after hashing. Changed or inaccessible files retain `UNKNOWN` plus a `file_hash_status`; this is not a guaranteed atomic snapshot. Does not persist raw log lines; RAW archive remains explicit opt-in.
- When ComfyUI is available, `/system_stats` takes precedence for Python, PyTorch and ComfyUI versions; `torch +cuNNN` is reported as **PyTorch CUDA build** in existing `environment.cuda` (never a driver/runtime toolkit claim). When the endpoint is down or incomplete, retain log-derived values and `UNKNOWN` instead of guessing.
- Optional `-ComfyUrl` accepts only HTTP loopback. Default remains `http://127.0.0.1:8188`, maintaining previous launch behavior; Configurator URL selection is not yet implemented.
- Python process metadata records start UTC when accessible and only asserts `API_LISTENER_PID_MATCH` when a unique local listening port owner can be matched. This is **not** proof that a process is genuine ComfyUI.
- Storage snapshots add a local drive alias (e.g. `C:`) to distinguish same-size volumes. Inspect for privacy before sharing.
- JSON snapshots stage through unique `.pending_*.tmp` in the same folder, flush to disk and are then moved into their final name. Existing `evidence_*.json` and JSONL records are untouched.

## Acceptance gates

- Windows PowerShell parser, Windows Forms smoke test, earlier v0.6 installer/uninstall/data-retention checks.
- `tests/test_evidence_reliability.ps1`: synthetic CUDA log without text leakage; two unique captures; source status, timestamps, localhost URL guard, isolated Windows providers including missing `storport`, mocked `/system_stats` returning PyTorch `2.10.0+cu130`, and shared-open ComfyUI log SHA-256.
- `python -m unittest discover -s tests -v`: analyzer and SQLite backwards compatibility.
- CI checks for the **current PR head**, not earlier v0.6 run.
- HOME v0.7 prior candidate: System `EMPTY`, Application `OK`, Queue on port 8190 `OK`, live log signature scan `PARTIAL` due full hash unknown. This is user-observed, **not** a test of the revised hash or API environment code. The HOME final acceptance remains required:
- HOME acceptance still required: Capture Evidence with Windows and ComfyUI sources enabled; read JSON and verify `sources.events_system`, `events_application`, `reliability`, `comfy_log_evidence`, `coverage`, `collector_version`, while ComfyUI is running.
- WORK RTX 4090 acceptance and long-running Collector durability remain separate future work.

## Known limitations / STOP

- Windows WER event metadata is captured only when accessible; full WER files, dump contents, system drivers and elevated collection are **not** enabled by default.
- Historical v0.3 continuous Collector retains single-instance, date-rotation and global retention gaps. Those belong to v0.8, not this PR.
- Sync WinForms capture can block the window during slow WMI calls; independent timeout of each Evidence source is **not yet implemented**.
- `Get-WinEvent` and CIM permissions may vary across HOME/WORK and cannot be certified by hosted Windows CI alone.
- Atomic rename prevents a partial file from appearing under the final name. It does **not** guarantee an application-level durable fsync across sudden hardware power loss.
- Existing v0.6 snapshots retain their original semantics and are never rewritten.
- No hardware stress tests, driver changes, service installation, privilege elevation or automatic ComfyUI restarts.

**STOP** if real HOME evidence is missing critical events, contains private log text, or reports misleading OK. Do not merge, declare production or deploy without device acceptance.
