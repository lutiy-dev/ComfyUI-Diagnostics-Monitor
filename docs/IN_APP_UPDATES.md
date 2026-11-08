# In-app updates: safety design and staged implementation

**Status:** LAB / UPDATE DISCOVERY ONLY. **No automatic installation in v0.5.**

The Dashboard now has **Check updates**. It only queries the official HTTPS GitHub releases/latest endpoint on explicit click. Compares installed version (installation.json, fallback 0.5.0-LAB), reports if a newer stable release exists, and *offers to open the official release page*. It never downloads packages, launches installers, changes ComfyUI, or changes Windows execution policy.

If no stable release is published, API unreachable, or metadata invalid: show a neutral failure message without changing anything. Offline tests validate release-version comparison. Network access to GitHub is initiated **only by clicking**; local Collector remains offline-only.

## Upgrade roadmap
One-click installation from the UI requires these gates before enabling:
1. Versioned signed Windows distribution or verified Authenticode signer; no untrusted self-signed certificate.
2. Download of explicitly chosen release from trusted source, verify the signed manifest and SHA256; no unsigned automatic execution.
3. Close running Dashboard/Collector safely; backup existing installed code and keep local data untouched.
4. Atomic swap/staged install and rollback on startup validation failure.
5. Report version, changelog, risks and user confirmation before applying.
6. HOME and WORK tests for in-place install, no duplicate collector, pinned shortcuts, preserves data, failure rollback and Windows Defender/Chrome clean verdict.

## Known limits
GitHub Actions success or checksum is not proof of benign/safe downloaded code. A draft PR is not a published release. Keep auto-install disabled until all required gates pass.
