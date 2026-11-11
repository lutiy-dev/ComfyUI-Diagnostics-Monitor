# In-app updates — v0.8 LAB policy

**Implemented:** Once per Dashboard launch, a separate PowerShell job reads the official GitHub published releases metadata (including LAB prereleases), using a bounded HTTPS request. It never pauses Dashboard rendering for the request. If a newer version is found, the **Update available** button becomes visible; clicking it requests confirmation before opening the official release page.

**Not implemented:** unattended download, extraction, in-place automatic installation, restart or update of a running Collector. Existing unsigned installer can be launched manually after review. No driver/model/config mutator, no scheduled task.

## Why automatic install is disabled

Current EXE is unsigned; SHA256 is an integrity checksum but does not authenticate the publisher. Automated execution would require an Authenticode signature and signer validation, atomic or staged program rollback, safe shutdown/restore of collector and open WinForms windows, and test evidence on HOME/WORK. An unattended update with any of those gates missing is **STOP**.

## Update checklist

1. Verify the GitHub release is authored by the expected repository and the release tag is newer than the installed `installation.json` version.
2. Download the matching official EXE or ZIP, verify its `.sha256` asset and Windows Defender/SmartScreen verdict.
3. Close Dashboard/Configurator/Collector; preserve local diagnostics and the previous installer.
4. Run EXE or BAT with explicit confirmation, inspect success/failure and the installed version.
5. Reopen and validate GUI/HUD/Collector before accepting the upgrade.

The release discovery query is read-only and does not send diagnostic files, prompts or user activity. A GitHub API error or missing release is neutral `UNAVAILABLE`; do not invent a version or install URL.
