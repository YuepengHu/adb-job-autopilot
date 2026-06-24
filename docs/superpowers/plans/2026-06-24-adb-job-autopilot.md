# Implementation Plan: ADB Job Autopilot

**Spec:** docs/superpowers/specs/2026-06-24-adb-job-autopilot-design.md
**Date:** 2026-06-24

## Tasks

### Phase 1: Foundation

- [ ] Task 1 — Create shared shell helpers for ADB device validation, logging, tapping, swiping, and delays.
- [ ] Task 2 — Add project README with bilingual usage, configuration, and calibration guidance.

### Phase 2: App Scripts

- [ ] Task 3 — Create `boss_apply.sh` with BOSS default coordinates and the approved loop flow. Depends on Task 1.
- [ ] Task 4 — Create `liepin_apply.sh` with Liepin default coordinates and the approved loop flow. Depends on Task 1.

### Phase 3: Verification

- [ ] Task 5 — Run shell syntax checks for all scripts.
- [ ] Task 6 — Verify the connected ADB device and run a single BOSS iteration when the phone is on the BOSS job list page.
- [ ] Task 7 — Leave Liepin ready for single-iteration verification once the phone is on the Liepin job list page.