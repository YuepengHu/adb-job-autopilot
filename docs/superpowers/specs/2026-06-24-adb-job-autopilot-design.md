# ADB Job Autopilot Design

## Goal

Create two small ADB scripts for the user's own Android phone:

- `boss_apply.sh` for BOSS Zhipin.
- `liepin_apply.sh` for Liepin.

Each script repeatedly opens the first visible job card, taps the app-specific communication button, returns to the job list, and scrolls down by about one job card.

## Scope

The first implementation uses fixed screen coordinates for the connected phone resolution `1260x2772`. The scripts are intentionally simple and configurable through environment variables, so coordinates and timings can be adjusted without editing the files.

Out of scope for this version:

- OCR-based button detection.
- Appium/UIAutomator setup.
- Reading or modifying resume content.
- Sending custom chat text beyond the app's own default action.

## Files

- `boss_apply.sh`: BOSS flow with a blue communication button.
- `liepin_apply.sh`: Liepin flow with an orange communication button.
- `README.md`: Usage, configuration, and safety notes.

## Runtime Flow

For each loop iteration:

1. Tap the first visible job card.
2. Wait for the detail page to load.
3. Tap the configured communication button coordinate.
4. Wait for the chat/detail transition.
5. Tap the top-left back coordinate twice.
6. Swipe upward by roughly one job card height.
7. Pause before the next iteration.

## Configuration

Both scripts expose these environment variables:

- `RUNS`: number of loop iterations, default `1`.
- `DELAY`: normal delay between actions, default `1` second.
- `JOB_X`, `JOB_Y`: first visible job card tap point.
- `BUTTON_X`, `BUTTON_Y`: communication button tap point.
- `BACK_X`, `BACK_Y`: top-left app back button tap point.
- `SWIPE_X`, `SWIPE_START_Y`, `SWIPE_END_Y`, `SWIPE_MS`: list scroll gesture.

The default BOSS list tap point is based on the captured screenshot: first card around `y=485-1018`, using `JOB_X=630`, `JOB_Y=690`.

## Safety And Error Handling

- The scripts check that exactly one authorized ADB device is connected before running.
- The scripts print all key coordinates and run counts before starting.
- `RUNS` defaults to `1` so the first execution is easy to verify.
- Delays are intentionally kept between actions to reduce accidental rapid tapping.
- The user explicitly approved real communication/tap actions for testing.

## Test Plan

1. Run `adb devices -l` and verify the device state is `device`.
2. Start with BOSS on a job list page and execute `RUNS=1 ./boss_apply.sh`.
3. Confirm one job was opened, communication was tapped, the app returned to the list, and the list scrolled.
4. Repeat with Liepin using `RUNS=1 ./liepin_apply.sh`.
5. Adjust `BUTTON_X/BUTTON_Y` if either app's button is not hit correctly.