# Roadmap — controlled increments

## Milestone 0 · Repository foundation (this draft PR)
- [x] Baseline repository audit and branch isolation
- [x] Agent scope/STOP rules
- [x] Local-first architecture and privacy boundaries
- [x] Git ignore for runtime diagnostics
- [ ] Draft PR reviewed and merged by owner

## Milestone 1 · Local read-only collector
- [ ] Review existing PowerShell v0.1 and v0.2 prototypes **as unverified inputs**
- [ ] GPU/Windows/ComfyUI collector with robust parsing and retention
- [ ] Example-only data fixtures, no real user logs
- [ ] Tests: Windows PowerShell syntax and runtime, missing GPU, missing server, event correlation
- [ ] HOME test: RTX 3070 Ti, no heavy render required

## Milestone 2 · Dashboard
- [ ] GPU metrics, VRAM, temperature, power; ComfyUI queue, current node, sampler progress
- [ ] Timeline: Windows + NVIDIA + ComfyUI
- [ ] Log search, incident export with review/redaction
- [ ] Error signature suggestions with CONFIRMED / HYPOTHESIS labels
- [ ] HOME / WORK Windows tests

## Milestone 3 · Release distribution
- [ ] Versioned zip/installer, checksums, changelog and rollback
- [ ] GitHub Actions static checks and test evidence
- [ ] Release only after both intended hardware profiles are verified

## Milestone 4 · Optional private sync
- [ ] Choose storage and access controls
- [ ] Opt-in, authenticated, encrypted upload and redaction tests
- [ ] Owner approval before implementation
