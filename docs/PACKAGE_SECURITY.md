# Windows package security policy · LAB

## Current alert

A Chrome screenshot from 2026-11-08 reports "Blocked dangerous download" for the GitHub Actions ZIP. This is a confirmed browser warning, **not** proof either of malware or a false positive. The specific Chrome Safe Browsing verdict and sample are unavailable, so the root cause is NOT CONFIRMED.

**STOP:** Do not select "Keep dangerous file", disable Chrome Safe Browsing or Microsoft Defender, add exclusions, or run the blocked package merely to continue testing. Do not relabel or repackage an unchanged blocked payload to evade detection.

## Gate added to GitHub Actions

The Windows ZIP job must:
- run PowerShell source syntax checks and install/uninstall smoke test;
- allow only 10 expected source/docs files (PS1, PY, MD), fail on binaries and unexpected payloads;
- reject unusually large files or selected high-confidence private-key/token signatures (limited pattern checks; not comprehensive);
- write `package-manifest.json` with Git commit and per-file SHA-256;
- publish the ZIP SHA-256 alongside the archive.

The manifest proves content identity relative to the CI run; **hashes do not prove that the software is safe**. GitHub-hosted CI does not guarantee local Defender/Safe Browsing clearance.

## Further security work required before release

- Review read-only behavior, local-only endpoints, installer/uninstaller file writes and permissions, PowerShell `ExecutionPolicy Bypass` use, installer source provenance.
- Run Windows Defender scan on the exact SHA256-matched artifact in a controlled test environment; record the actual Defender result and threat ID if any.
- Investigate Chrome's specific classification through appropriate browser/vendor reporting. Do not assume all alerts are false positives.
- Provide signed PowerShell/EXE/MSI distribution only after choosing a legitimate signing identity, certificate provisioning and safe key handling. **No self-signed cert is to be presented as publisher-trusted.**
- Remove unnecessary use of `-ExecutionPolicy Bypass` from launch shortcuts as a separate reviewed change, with realistic Windows 10 compatibility tests. A PowerShell script cannot be considered signed without verifying its Authenticode status.

## Diagnostic fallback without installing blocked archive

Keep using the previously executed local HOME collector v0.3 and v0.4 dashboard baseline until the package investigation is complete. For ChatGPT analysis, review only opted-in diagnostic extracts, not public GitHub uploads.

## Status and safety

Source code is public in the GitHub repository, private logs are not. This security check does not add network listeners, change Defender or Windows security settings, sign code, or deploy to the user. Real Chrome and HOME/WORK installer tests remain NOT TESTED.
