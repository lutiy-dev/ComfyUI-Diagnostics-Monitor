# v0.9 LAB update channel fix — 2026-11-12

Baseline: `feat/live-gpu-process-list-v09-20261112` at `28e544cbc586c343709f434016d09b2fe715a072`. The only published GitHub Release at inspection was `v0.8.0-LAB`; v0.9 is a Draft PR / Windows Actions artifact (not a Release).

## Root cause (VERIFIED)

`Get-DiagnosticsReleaseStatus` checks the published GitHub Releases API only. For an installed `0.9.0-LAB-CANDIDATE` with published `v0.8.0-LAB`, semantic comparison said `UP_TO_DATE`, which was displayed as `Установлена актуальная версия`. This did **not** prove the CI-installed candidate was current. Rebuilt CI artifacts share the same version string, so simple version comparison cannot distinguish them.

## Minimal fix

- The release checker now returns `LAB_CANDIDATE` when an installed unpublished v0.9 candidate is equal to or newer than the most recent published Release.
- Settings displays **LAB-сборка: обновления ищи в GitHub Actions, пока нет релиза v0.9** and a button **Открыть сборки**.
- The button requests confirmation then opens only the official repository's GitHub Actions Windows installer workflow. It never automatically downloads or launches a PR artifact.
- Offline deterministic tests assert candidate vs Release semantics and preserve the ability to identify a genuinely newer published Release.

## Installation and safety

For a v0.9 LAB candidate download the **exact desired successful workflow artifact** and confirm the run's source commit/branch before running the unsigned EXE. Close Diagnostics Monitor (and its hidden Collector) before re-running the installer. The installer supports an in-place upgrade and retains local diagnostic JSON/JSONL and language/ComfyUI port preferences. No update can be claimed by this app until install and post-install version/source are verified.

## Future requirements (not implemented)

For reliable one-click channel-aware updates: create versioned/signed LAB prereleases or authenticated artifact discovery with per-build commit identity and SHA256/publisher verification, safe Collector shutdown, atomic rollback and explicit approval. Without these safeguards, automated installation of unsigned CI artifacts is prohibited.

Status: CODE GENERATED; Windows CI and HOME manual runtime verification required. No changes to main, drivers, ComfyUI or local installations.
