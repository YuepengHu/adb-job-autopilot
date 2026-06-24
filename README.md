# ADB Job Autopilot / ADB 求职自动操作

Small ADB scripts for repeating the same phone-side job application flow on BOSS Zhipin and Liepin.

用于在手机端 BOSS 直聘和猎聘上重复执行固定的职位沟通流程。

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

## Flow / 流程

Each iteration does this:

每一轮执行：

1. Tap the first visible job card / 点击第一个可见职位。
2. Tap the communication button / 点击沟通按钮。
3. Tap the top-left back point twice / 点击左上角返回两次。
4. Swipe the list upward by about one job card / 向上滑动约一个职位卡片。

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
| `JOB_X`, `JOB_Y` | App-specific | First job card tap point / 第一个职位点击点 |
| `BUTTON_X`, `BUTTON_Y` | App-specific | Communication button tap point / 沟通按钮点击点 |
| `BACK_X`, `BACK_Y` | `70,220` | Top-left back tap point / 左上角返回点击点 |
| `SWIPE_X` | `630` | Swipe x coordinate / 滑动横坐标 |
| `SWIPE_START_Y` | `1850` | Swipe start y / 滑动起点纵坐标 |
| `SWIPE_END_Y` | `1290` | Swipe end y / 滑动终点纵坐标 |
| `SWIPE_MS` | `350` | Swipe duration in ms / 滑动耗时毫秒 |
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

These defaults target the connected `1260x2772` phone.

默认坐标面向当前已连接的 `1260x2772` 手机。

| Script | Job tap | Communication tap | Back tap | Swipe |
| --- | --- | --- | --- | --- |
| `boss_apply.sh` | `630,690` | `1010,2585` | `70,220` | `630,1850 -> 630,1290` |
| `liepin_apply.sh` | `630,720` | `990,2585` | `70,220` | `630,1850 -> 630,1290` |

## Notes / 注意

- These scripts perform real taps. They may trigger real communication/application actions.
- If a popup appears, stop and adjust the flow or handle it manually.
- If the button is not hit, rerun with adjusted `BUTTON_X` and `BUTTON_Y`.
- If multiple devices are connected, set `ADB_SERIAL=<serial>`.

- 脚本会执行真实点击，可能触发真实沟通或投递。
- 如果出现弹窗，先停止脚本，手动处理或调整流程。
- 如果按钮没有点中，通过 `BUTTON_X` 和 `BUTTON_Y` 微调。
- 如果连接了多台设备，使用 `ADB_SERIAL=<serial>` 指定设备。