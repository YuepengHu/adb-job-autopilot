# ADB Job Autopilot / ADB 求职自动操作

Small ADB scripts for repeating the same phone-side job application flow on BOSS Zhipin and Liepin.

用于在手机端 BOSS 直聘和猎聘上重复执行固定的职位沟通流程。

The scripts now prefer Android UI dumps for job/button detection, with coordinate fallback and optional OCR fallback for interruptions.

脚本现在优先使用 Android UI dump 识别职位和按钮，同时保留坐标兜底，并可用 OCR 兜底识别异常中断页面。

## Requirements / 前置条件

- One Android phone connected with USB debugging authorized.
- `adb devices -l` shows exactly one device with state `device`.
- The target app is already opened on its job list page.

- 手机已连接电脑，并授权 USB 调试。
- `adb devices -l` 只显示一台状态为 `device` 的设备。
- 目标 App 已经停在职位列表页。

## Usage / 使用

```bash
cd ~/Yuepeng/github/adb-job-autopilot
chmod +x boss_apply.sh liepin_apply.sh

# BOSS: run one real iteration / BOSS：真实执行 1 轮
RUNS=1 ./boss_apply.sh

# Liepin: run one real iteration / 猎聘：真实执行 1 轮
RUNS=1 ./liepin_apply.sh
```

Increase `RUNS` only after one iteration looks correct.

确认单轮动作正确后，再增大 `RUNS`。

```bash
RUNS=5 ./boss_apply.sh
RUNS=5 ./liepin_apply.sh
```

## Menu Bar App / 菜单栏 App

Build and open the native macOS menu bar launcher:

构建并打开原生 macOS 菜单栏启动器：

```bash
cd ~/Yuepeng/github/adb-job-autopilot
./build_menubar_app.sh --open
```

It creates one menu bar item: `投递`.

它会创建一个顶部菜单栏入口：`投递`。

- Open `投递` and choose the run count / 打开 `投递` 并选择岗位数量。
- Choose `Start BOSS` to start `boss_apply.sh` / 选择 `Start BOSS` 启动 `boss_apply.sh`。
- Choose `Start Liepin` to start `liepin_apply.sh` / 选择 `Start Liepin` 启动 `liepin_apply.sh`。
- Use `Stop Running Script` to stop a running script / 使用 `Stop Running Script` 停止正在运行的脚本。
- Use `Quit` to quit the menu bar app / 使用 `Quit` 退出菜单栏 App。
- Logs are written under `logs/` / 日志写入 `logs/`。

The menu bar app uses `MENU_RUNS=5` by default.

菜单栏 App 默认使用 `MENU_RUNS=5`。

```bash
MENU_RUNS=3 ./build_menubar_app.sh --open
```

## Flow / 流程

Each iteration does this:

每一轮执行：

1. Tap the first visible job card / 点击第一个可见职位。
2. Tap the new communication button, or return directly if it is already `继续沟通/继续聊` / 点击新的沟通按钮；如果是 `继续沟通/继续聊`，说明已投递，直接返回。
3. Tap the top-left back point twice / 点击左上角返回两次。
4. Advance by one visible job using short slow swipes and UI verification / 使用短慢滑动和 UI 校验推进一个可见职位。

## Configuration / 配置

All coordinates and timings can be overridden with environment variables.

所有坐标和等待时间都可以通过环境变量覆盖。

| Variable | Default | Meaning |
| --- | ---: | --- |
| `RUNS` | `1` | Number of loop iterations / 循环次数 |
| `DELAY` | `1` | Pause after each iteration / 每轮结束后的暂停秒数 |
| `OPEN_DELAY` | `2` | Wait after opening a job / 打开职位后的等待秒数 |
| `POST_BUTTON_DELAY` | `2` | Wait after tapping communication / 点击沟通后的等待秒数 |
| `RETURN_DELAY` | `1` | Wait between back taps / 返回点击之间的等待秒数 |
| `WAKE_SCREEN` | `1` | Wake the screen before running / 运行前唤醒屏幕 |
| `KEEP_AWAKE` | `1` | Keep screen awake while connected through USB / USB 连接时保持亮屏 |
| `SMART_TAP` | `1` | Use UI dump to tap job/buttons when possible / 尽可能用 UI dump 点击职位和按钮 |
| `SMART_SCROLL` | `1` | Use verified small swipes to advance one job / 用可验证短滑推进一个职位 |
| `PAGE_GUARD` | `1` | Stop or recover on unexpected pages / 遇到异常页面时停止或恢复 |
| `OCR_FALLBACK` | `1` | Use tesseract OCR when UI dump is insufficient / UI dump 不足时使用 tesseract OCR |
| `JOB_X`, `JOB_Y` | App-specific | First job card tap point / 第一个职位点击点 |
| `BUTTON_X`, `BUTTON_Y` | App-specific | Communication button tap point / 沟通按钮点击点 |
| `BACK_X`, `BACK_Y` | `70,220` | Top-left back tap point / 左上角返回点击点 |
| `SWIPE_X` | `630` | Swipe x coordinate / 滑动横坐标 |
| `SWIPE_START_Y` | App-specific | Fallback swipe start y / 兜底滑动起点纵坐标 |
| `SWIPE_END_Y` | App-specific | Fallback swipe end y / 兜底滑动终点纵坐标 |
| `SWIPE_MS` | `900` | Swipe duration in ms / 滑动耗时毫秒 |
| `STEP_SWIPE_*` | App-specific | Small verified swipe settings / 可验证短滑配置 |
| `SMART_SCROLL_MAX_STEPS` | `5` | Max small swipes for one job advancement / 单职位推进最多短滑次数 |
| `SMART_SCROLL_MIN_STEPS` | `2` | Minimum small swipes before accepting advancement / 接受推进成功前至少短滑次数 |
| `DRY_RUN` | `0` | Print actions and skip device validation when `1` / 为 `1` 时只打印动作并跳过设备检查 |

Examples / 示例：

```bash
# Only print actions / 只打印动作
DRY_RUN=1 RUNS=1 ./boss_apply.sh

# Move BOSS communication button slightly left / 微调 BOSS 沟通按钮到更靠左
BUTTON_X=960 BUTTON_Y=2585 RUNS=1 ./boss_apply.sh

# Slow down if the app loads slowly / 如果 App 加载慢，增加等待时间
OPEN_DELAY=3 POST_BUTTON_DELAY=3 RUNS=1 ./liepin_apply.sh
```

## Default Coordinates / 默认坐标

These fallback defaults target the connected `1260x2772` phone. With `SMART_TAP=1` and `SMART_SCROLL=1`, UI-detected points are used first.

这些兜底坐标面向当前已连接的 `1260x2772` 手机。启用 `SMART_TAP=1` 和 `SMART_SCROLL=1` 时，会优先使用 UI 识别到的位置。

| Script | Job tap | Communication tap | Back tap | Swipe |
| --- | --- | --- | --- | --- |
| `boss_apply.sh` | `630,690` | `1010,2585` | `70,220` | `630,1750 -> 630,1420` |
| `liepin_apply.sh` | `630,1190` | `820,2585` | `70,220` | `630,1800 -> 630,1450` |

## OCR / OCR

OCR fallback uses `tesseract` with `chi_sim+eng`. On this machine both languages are installed.

OCR 兜底使用 `tesseract` 的 `chi_sim+eng`。当前电脑已安装这两个语言包。

## Notes / 注意

- These scripts perform real taps. They may trigger real communication/application actions.
- If a popup appears, stop and adjust the flow or handle it manually.
- If an ad/error page appears, the guard will try a bounded close/back recovery; if recovery is unsafe, it stops.
- If the button is not hit, rerun with adjusted `BUTTON_X` and `BUTTON_Y`.
- If multiple devices are connected, set `ADB_SERIAL=<serial>`.

- 脚本会执行真实点击，可能触发真实沟通或投递。
- 如果出现弹窗，先停止脚本，手动处理或调整流程。
- 如果出现广告/报错页面，页面守卫会尝试有限次数关闭或返回；如果无法安全恢复，会停止。
- 如果按钮没有点中，通过 `BUTTON_X` 和 `BUTTON_Y` 微调。
- 如果连接了多台设备，使用 `ADB_SERIAL=<serial>` 指定设备。