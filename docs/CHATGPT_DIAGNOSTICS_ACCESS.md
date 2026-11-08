# ChatGPT diagnostics access — opt-in design

**State:** DESIGN / NOT CONNECTED. ChatGPT has no direct access to local Windows/ComfyUI files without user sharing or an authorized connector.

## Goal
Allow a user to ask ChatGPT to read synchronized diagnostics from HOME/WORK and compare failures without exposing raw personal data in public GitHub or allowing remote machine control.

## Stage 1: manual, offline incident bundle (recommended first)
1. User selects an incident/time range and data sources in Dashboard.
2. Collector produces an **opt-in local export** containing a manifest, normalized hardware/events, and curated ComfyUI snippets with source timestamps.
3. Preview and redact before export: usernames, paths, prompts, API keys, tokens, authentication URLs, machine IDs, client files, raw Python trace arguments and any potentially sensitive content.
4. User attaches the export to a ChatGPT conversation. Analysis includes causality caveats and evidence confidence.
5. No automatic external upload. Export can be deleted by user. Original local diagnostic store remains intact.

**Only normalized codes/metrics** may be exported by default. Raw logs require separate user-reviewed selection, never blanket upload. Exports should be size-limited and contain no secret-bearing configuration.

## Stage 2: private library or connector (requires approval)
- Option A: user-selected **private Google Drive** folder with sanitized archives. A connected Google Drive app can retrieve files under its supported permissions; availability/automation must be separately tested.
- Option B: authenticated read-only diagnostics API through a purpose-built private connector. Define least-privilege OAuth/scoped tokens, expiry, encryption, rate limiting, host authentication and deletion controls. No public unauthenticated endpoints.
- HOME and WORK publish only if user explicitly enables synchronization. Separate service credentials may be required; do not store them in GitHub.
- Distinguish pull on user request from ongoing monitoring; ChatGPT does not automatically see local logs or query offline computers.
- Never route raw telemetry to a **public** GitHub repo, GitHub Pages, public issue, or public Release artifact.

## Required tests before enabling sync
- export with synthetic secrets and Windows paths: redaction test PASS;
- client/NDA prompt and command-line leakage tests PASS;
- access denied with missing/expired credentials;
- no external network access in local-only mode;
- user revocation and deletion of copied archives confirmed;
- audit of exactly which files the connector can read;
- restore points / privacy retention / failure handling documented.

## Stop conditions
Any accidental private data publication, unapproved upload, credential storage in source, insecure server exposure, or nondeterministic redaction = STOP. No automatic remote repair or ComfyUI mutation.

Next deliverable after HUD validation: independent incident bundle exporter and comprehensive redaction tests, **before** any sync implementation.
