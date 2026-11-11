# Agent operating rules — ComfyUI Diagnostics Monitor

## Purpose
Build a read-only, local-first Windows diagnostics monitor for NVIDIA GPU and ComfyUI. Support HOME (RTX 3070 Ti 8 GB) and WORK (RTX 4090 24 GB) without hardcoded user paths.

## Mandatory workflow
INSPECT → PLAN → CHANGE ON FEATURE BRANCH → STATIC VALIDATION → WINDOWS RUNTIME TEST → PR REVIEW → RELEASE.
- Never modify production ComfyUI workflows, models, driver settings, registry TDR values, or dependencies without explicit approval.
- One issue/feature → one branch → one PR. Do not merge without approval.
- Distinguish GENERATED, VALIDATED, TESTED, and PRODUCTION. A passing lint check is not a Windows runtime test.
- Record baseline commit, scope, changed files, validation evidence, stop conditions, and rollback.

## Security and privacy
- Treat raw Windows event logs, paths, command lines, GPU process listings, ComfyUI prompts, and workflow names as potentially sensitive.
- Default to localhost-only collection and on-device storage; no telemetry upload, no automatic GitHub Issues, no cloud sync.
- Do not commit captured logs, SQLite DBs, crash dumps, hostnames, usernames, tokens, client content, or secrets.
- Sanitize/redact before explicitly authorized exports; make export opt-in with preview.
- Read ComfyUI via localhost interfaces only. No remote listener by default.
- Collection must be bounded (retention, rotation, sampling intervals), fail safely, and never restart/kill ComfyUI.

## Data quality
Every event needs a source (Windows, NVIDIA, ComfyUI), machine-local timestamp + UTC timestamp where possible, machine alias (HOME/WORK, not host identifier), severity, raw/normalized code, and correlation window. Correlation is an inference, not proof of root cause.

## Testing & STOP
- Unit tests for parsers, log rotation, duplicate events, timestamp alignment, Unicode Windows paths, absent GPU/ComfyUI, API errors, and SQLite idempotence.
- Verify permissions needed to read Windows Event Log. Never require administrator by default.
- STOP if unexpected outbound traffic, credential exposure, uncontrolled file growth, ComfyUI mutation, GPU instability, or failing critical regression.
- Windows TESTED requires real host execution and evidence; record GPU driver, OS, ComfyUI version, test commit, and result.
