# UI Legend Percentages — LAB

Baseline: PR #13 UI candidate commit `3114eddefd8c080c0e8dc91db27de3569000d043`.

## Scope

The Dashboard graph legend now displays GPU load and VRAM allocation percentages alongside the existing colored series labels. A monospaced font and shared field-width expression align percentages to the right. Data comes from the same latest collector GPU sample used in the upper labels; no new source, polling, API request, or schema. Invalid/unavailable GPU samples display `--`. Collector STALE remains explicitly indicated in the window status; legend values may correspond to the last sample when STALE. GPU cyan / VRAM orange preserved. HUD still derives curves from the original two series by unchanged series names.

## Not implemented: Clear Memory

Do not add a generic **Clear Memory** command without agreeing the actual target and side effects. RAM is not cleared through ordinary application logic. A possible `ComfyUI cache/unload` operation would mutate local ComfyUI runtime and could interrupt workflow/model cache reuse. Requires explicit owner approval and a separate PR defining idle gate, confirmation, timeout, localhost-only endpoint, safety and rollback. Especially important while HOME RTX 3070 Ti has recurring display timeouts and LiveKernelEvent 141. No GPU reset, process kill, cache deletion, model unload or OS memory purge is authorized by this UI request alone.

## Acceptance

- Windows PowerShell parser; WinForms initialization; HUD F9 transition; collector/evidence regression; Windows installer and package inventory must pass on exact head.
- HOME/WORK screenshot review: legend shows same GPU/VRAM percentages as headline after fresh sample; numeric right alignment at 100% and single-digit; no graph clipping at 100/125/150% DPI; UNKNOWN displays `--`; collector STALE is visible.
- Runtime acceptance is NOT CONFIRMED until user visually checks the packaged Windows build.

Rollback: prior PR #13 ZIP and branch. No changes to installed HOME/WORK data, ComfyUI, NVIDIA drivers, or telemetry history.
