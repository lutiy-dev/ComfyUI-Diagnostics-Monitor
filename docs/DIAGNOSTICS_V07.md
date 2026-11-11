# Evidence Reliability v0.7 — LAB CANDIDATE

**Status:** VERIFIED LAB CANDIDATE — Windows CI PASS, WORK RTX 4090 on-device smoke and online Evidence PASS (2026-11-10). Latest patch HOME RTX 3070 Ti final runtime and continuous Collector durability NOT TESTED. NOT PRODUCTION.

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
- WORK RTX 4090 on-device acceptance: PASS for installation, Windows GUI smoke, offline Evidence, /system_stats and live-log SHA-256 on the latest v0.7 patch. See the verified test matrix below. Long-running Collector durability remains separate future work.

## Runtime verification — 2026-11-10

| Test | HOME RTX 3070 Ti | WORK RTX 4090 |
| --- | --- | --- |
| Installed v0.6 baseline, Dashboard/HUD | PASS (prior baseline) | Not evaluated as v0.6 baseline |
| v0.7 Windows Event provider isolation | PASS: System EMPTY, Application OK | PASS: System EMPTY, Application OK |
| v0.7 GPU / OS / process / storage sampling | PASS | PASS |
| v0.7 local ComfyUI queue | PASS on H3 LAB :8190 | PASS on ARCHVIZ_LAB :8188 |
| New v0.7 /system_stats patch | NOT TESTED on latest patch | PASS: ComfyUI 0.44.0, Python 3.13.12, PyTorch 2.12.1+cu130, CUDA build 13.0 |
| New shared-read log SHA-256 patch | NOT TESTED on latest patch | PASS: 40,790 tail bytes, 64-hex SHA256, STABLE_BEST_EFFORT |
| Live log signature scan | PASS on previous v0.7: 7 signatures, hash PARTIAL | PASS on latest v0.7: 2 normalized signatures (not proof of two failures) |
| Windows install and shortcuts | NOT TESTED for latest package on HOME | PASS on WORK |
| Multi-hour collector/rotation/sleep-resume | NOT TESTED | NOT TESTED |

WORK Evidence readback on 2026-11-10 recorded: Environment=OK, Queue=OK, Log=OK, HashStatus=STABLE_BEST_EFFORT, SHA256Valid=True, TailBytes=40790, Signatures=2, available=9, missing=1 (System Events EMPTY). The active ComfyUI process was confirmed running from ARCHVIZ_LAB on port 8188; log path was independently inspected and recently updated before capture. A previous comfyui_8188.log was stale and deliberately not selected. No raw log, prompt, machine identity, executable command line, or host user directory is published in the repository.

HOME earlier Evidence capture confirmed System=EMPTY and Application=OK after provider isolation, but before latest /system_stats and shared hashing patch. Do not claim full HOME acceptance of the revised code.

Data quality: 'aimdo=UNKNOWN' may leave Environment PARTIAL on a machine where that optional component was not observed. A missing ComfyUI log or offline API is UNAVAILABLE, not invented data. File hashing is still best-effort against concurrent modifications.

**Release gate:** no Production claim, no merge of Draft PR #11/#12, no automatic replacement of HOME/WORK installation, and no release signed as stable until the owner approves integration and the remaining durability tests. The Windows artifact is a candidate for controlled manual install/rollback.

## Known limitations / STOP

- Windows WER event metadata is captured only when accessible; full WER files, dump contents, system drivers and elevated collection are **not** enabled by default.
- Historical v0.3 continuous Collector retains single-instance, date-rotation and global retention gaps. Those belong to v0.8, not this PR.
- Sync WinForms capture can block the window during slow WMI calls; independent timeout of each Evidence source is **not yet implemented**.
- `Get-WinEvent` and CIM permissions may vary across HOME/WORK and cannot be certified by hosted Windows CI alone.
- Atomic rename prevents a partial file from appearing under the final name. It does **not** guarantee an application-level durable fsync across sudden hardware power loss.
- Existing v0.6 snapshots retain their original semantics and are never rewritten.
- No hardware stress tests, driver changes, service installation, privilege elevation or automatic ComfyUI restarts.

**STOP** if real HOME evidence is missing critical events, contains private log text, or reports misleading OK. Do not merge, declare production or deploy without device acceptance.
