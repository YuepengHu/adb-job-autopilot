# ADB Job Autopilot Design / ADB 求职自动操作设计

## Goal / 目标

Create two small ADB scripts for the user's own Android phone.

为用户自己的 Android 手机创建两个轻量级 ADB 脚本。

- `boss_apply.sh`: for BOSS Zhipin / 用于 BOSS 直聘。
- `liepin_apply.sh`: for Liepin / 用于猎聘。

Each script repeatedly opens the first visible job card, taps the app-specific communication button, returns to the job list, and scrolls down by about one job card.

每个脚本都会重复执行：打开当前列表里第一个可见职位，点击对应 App 的沟通按钮，返回职位列表，然后向下滑动约一个职位卡片的距离。

## Scope / 范围

The first implementation uses fixed screen coordinates for the connected phone resolution `1260x2772`. The scripts are intentionally simple and configurable through environment variables, so coordinates and timings can be adjusted without editing the files.

第一版基于当前已连接手机的分辨率 `1260x2772` 使用固定坐标。脚本会保持简单，并通过环境变量暴露坐标和等待时间，这样后续不需要改文件也能微调。

Out of scope for this version / 本版本不包含：

- OCR-based button detection / 基于 OCR 的按钮识别。
- Appium/UIAutomator setup / Appium 或 UIAutomator 工程化配置。
- Reading or modifying resume content / 读取或修改简历内容。
- Sending custom chat text beyond the app's own default action / 发送额外自定义聊天文本。

## Files / 文件

- `boss_apply.sh`: BOSS flow with a blue communication button / BOSS 直聘流程，目标是蓝色沟通按钮。
- `liepin_apply.sh`: Liepin flow with an orange communication button / 猎聘流程，目标是橙色沟通按钮。
- `README.md`: usage, configuration, and safety notes / 使用方式、配置项和安全提示。

## Runtime Flow / 运行流程

For each loop iteration / 每一轮循环：

1. Tap the first visible job card / 点击第一个可见职位卡片。
2. Wait for the detail page to load / 等待职位详情页加载。
3. Tap the configured communication button coordinate / 点击已配置的沟通按钮坐标。
4. Wait for the chat/detail transition / 等待进入聊天页或完成页面跳转。
5. Tap the top-left back coordinate twice / 点击左上角返回坐标两次。
6. Swipe upward by roughly one job card height / 向上滑动大约一个职位卡片高度。
7. Pause before the next iteration / 暂停一小段时间后进入下一轮。

## Configuration / 配置

Both scripts expose these environment variables.

两个脚本都会暴露以下环境变量。

- `RUNS`: number of loop iterations, default `1` / 循环次数，默认 `1`。
- `DELAY`: normal delay between actions, default `1` second / 常规动作间隔，默认 `1` 秒。
- `JOB_X`, `JOB_Y`: first visible job card tap point / 第一个可见职位卡片的点击坐标。
- `BUTTON_X`, `BUTTON_Y`: communication button tap point / 沟通按钮点击坐标。
- `BACK_X`, `BACK_Y`: top-left app back button tap point / App 左上角返回按钮点击坐标。
- `SWIPE_X`, `SWIPE_START_Y`, `SWIPE_END_Y`, `SWIPE_MS`: list scroll gesture / 列表滑动手势配置。

The default BOSS list tap point is based on the captured screenshot: first card around `y=485-1018`, using `JOB_X=630`, `JOB_Y=690`.

BOSS 默认职位点击点基于当前截图：第一张卡片大约在 `y=485-1018`，默认使用 `JOB_X=630`、`JOB_Y=690`。

## Safety And Error Handling / 安全和错误处理

- The scripts check that exactly one authorized ADB device is connected before running / 脚本启动前检查是否只有一台已授权的 ADB 设备连接。
- The scripts print all key coordinates and run counts before starting / 启动前打印关键坐标和循环次数。
- `RUNS` defaults to `1` so the first execution is easy to verify / `RUNS` 默认是 `1`，方便先做单轮验证。
- Delays are intentionally kept between actions to reduce accidental rapid tapping / 动作之间保留延迟，降低误触和过快点击风险。
- The user explicitly approved real communication/tap actions for testing / 用户已明确允许测试时真实点击沟通按钮。

## Test Plan / 测试计划

1. Run `adb devices -l` and verify the device state is `device` / 运行 `adb devices -l`，确认设备状态是 `device`。
2. Start with BOSS on a job list page and execute `RUNS=1 ./boss_apply.sh` / 在 BOSS 职位列表页执行 `RUNS=1 ./boss_apply.sh`。
3. Confirm one job was opened, communication was tapped, the app returned to the list, and the list scrolled / 确认脚本打开了一个职位、点击了沟通、返回列表并完成滑动。
4. Repeat with Liepin using `RUNS=1 ./liepin_apply.sh` / 在猎聘中用 `RUNS=1 ./liepin_apply.sh` 重复验证。
5. Adjust `BUTTON_X/BUTTON_Y` if either app's button is not hit correctly / 如果任一 App 的按钮没有点准，调整 `BUTTON_X/BUTTON_Y`。