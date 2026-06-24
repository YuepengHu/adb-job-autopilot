# Implementation Plan: ADB Job Autopilot

**Spec:** docs/superpowers/specs/2026-06-24-adb-job-autopilot-design.md
**Date:** 2026-06-24

## Tasks

### Phase 1: UI Detection Foundation

- [ ] Task 1 — Add shared helpers for Android UI dump capture, foreground package detection, XML text search, and bounds parsing.
- [ ] Task 2 — Add optional OCR fallback helpers that use `tesseract` when available and degrade safely when unavailable.
- [ ] Task 3 — Add page guard helpers that detect unexpected packages, ad/error/close/skip text, and unsafe pages.

### Phase 2: One-Job Advancement

- [ ] Task 4 — Update BOSS script defaults and flow to use guarded job-card tapping and slower one-card advancement.
- [ ] Task 5 — Update Liepin script defaults and flow to use guarded job-card tapping and slower one-card advancement.
- [ ] Task 6 — Keep coordinate fallback available through environment variables for cases where UI detection fails.

### Phase 3: Menu Bar Launcher

- [ ] Task 7 — Add native Swift menu bar app with one `投递` status item, run-count configuration, and BOSS/Liepin actions.
- [ ] Task 8 — Add build script for compiling the menu bar app bundle and placing runtime logs under `logs/`.
- [ ] Task 9 — Document how to launch, stop, and configure the menu bar app.

### Phase 4: Verification

- [ ] Task 10 — Run shell syntax checks and Swift compilation.
- [ ] Task 11 — Verify BOSS and Liepin dry-run flows with guards enabled.
- [ ] Task 12 — Verify menu bar app builds, launches as one status item, and exposes run-count and BOSS/Liepin actions.