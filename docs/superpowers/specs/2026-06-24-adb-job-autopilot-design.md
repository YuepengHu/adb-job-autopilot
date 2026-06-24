# ADB Job Autopilot Design / ADB 求职自动操作设计

## Goal / 目标

Create ADB automation for the user's own Android phone, with script entry points and a macOS menu bar launcher.

为用户自己的 Android 手机创建 ADB 自动操作工具，并提供脚本入口和 macOS 菜单栏启动器。

- `boss_apply.sh`: for BOSS Zhipin / 用于 BOSS 直聘。
- `liepin_apply.sh`: for Liepin / 用于猎聘。
- `ADB Job Autopilot.app`: macOS menu bar launcher with one menu item and BOSS/Liepin actions inside / macOS 菜单栏启动器，使用一个菜单栏入口，并在子菜单中区分 BOSS 和猎聘操作。

Each script repeatedly opens the current target job card, taps the app-specific communication button, returns to the job list, and advances by exactly one job card when possible.

每个脚本都会重复执行：打开当前目标职位，点击对应 App 的沟通按钮，返回职位列表，并尽可能精确推进到下一个职位卡片。

## Scope / 范围

The upgraded implementation still supports coordinate fallback for the connected phone resolution `1260x2772`, but the default behavior becomes structure-aware. It uses Android UI dumps to identify visible job nodes, communication buttons, page state, and possible ad/error screens. Screenshot OCR is used only as a fallback when the UI tree is insufficient.

升级版仍保留当前已连接手机分辨率 `1260x2772` 的坐标兜底，但默认流程改为结构识别优先。脚本会通过 Android UI dump 识别可见职位节点、沟通按钮、页面状态以及可能的广告/报错页面；只有 UI 树不足时才使用截图 OCR 作为 fallback。

In scope for this version / 本版本包含：

- One-job-at-a-time list advancement / 每次尽量只推进一个职位。
- UI dump based button and page detection / 基于 UI dump 的按钮和页面识别。
- OCR fallback for unexpected ad/error pages / 用于异常广告/报错页面的 OCR 兜底。
- Native macOS menu bar launcher with one configurable menu / 原生 macOS 菜单栏启动器，包含一个可配置菜单。

Out of scope for this version / 本版本不包含：

- Appium/UIAutomator setup / Appium 或 UIAutomator 工程化配置。
- Reading or modifying resume content / 读取或修改简历内容。
- Sending custom chat text beyond the app's own default action / 发送额外自定义聊天文本。

## Files / 文件

- `boss_apply.sh`: BOSS flow with a blue communication button / BOSS 直聘流程，目标是蓝色沟通按钮。
- `liepin_apply.sh`: Liepin flow with an orange communication button / 猎聘流程，目标是橙色沟通按钮。
- `lib/adb_job_common.sh`: shared shell helpers / 共享 shell helper。
- `lib/adb_job_ui.sh`: UI dump, OCR fallback, page guard, and one-card scroll helpers / UI dump、OCR 兜底、页面守卫和单卡片滚动 helper。
- `menu_bar/JobAutopilotMenu.swift`: native macOS menu bar launcher / 原生 macOS 菜单栏启动器。
- `build_menubar_app.sh`: builds the menu bar app bundle / 构建菜单栏 App bundle。
- `README.md`: usage, configuration, and safety notes / 使用方式、配置项和安全提示。

## Runtime Flow / 运行流程

For each loop iteration / 每一轮循环：

1. Verify the current foreground app and page / 校验当前前台 App 和页面。
2. Read visible job nodes from the UI tree / 从 UI 树读取当前可见职位节点。
3. Tap the target visible job card / 点击目标可见职位卡片。
4. Wait for the detail page to load / 等待职位详情页加载。
5. Detect the app-specific communication button by text; tap only new communication actions and skip already-connected actions / 通过文字识别对应 App 的沟通按钮；只点击新的沟通动作，遇到已沟通动作则跳过。
6. Wait for the chat/detail transition / 等待进入聊天页或完成页面跳转。
7. Tap the top-left back coordinate twice / 点击左上角返回坐标两次。
8. Verify the list page again / 再次校验是否回到职位列表。
9. Advance by one job card using a slow, verified scroll / 使用慢速且可验证的滑动推进一个职位。
10. Pause before the next iteration / 暂停一小段时间后进入下一轮。

## Page Guard And OCR / 页面守卫和 OCR

The scripts use a layered guard.

脚本使用分层守卫。

1. Check the focused package name / 检查前台包名。
2. Dump the Android UI tree and search for expected app text, job nodes, and communication buttons / dump Android UI 树，查找预期 App 文案、职位节点和沟通按钮。
3. Search for known interruption text such as ad, skip, close, error, reload, network, or login prompts / 查找广告、跳过、关闭、报错、重试、网络、登录等中断文案。
4. If the UI tree is insufficient, capture a screenshot and run OCR when available / 如果 UI 树不足，抓取截图并在可用时运行 OCR。
5. If the script cannot recover safely, it stops instead of continuing blind taps / 如果无法安全恢复，脚本停止，不继续盲点。

OCR is not used for the normal happy path when UI dump can identify controls. This keeps the loop faster and reduces OCR false positives.

正常路径中只要 UI dump 能识别控件，就不使用 OCR；这样循环更快，也能减少 OCR 误识别。

## Menu Bar Launcher / 菜单栏启动器

The macOS menu bar launcher is a native Swift AppKit app. It creates one status bar item named `投递`, with menu actions for BOSS and Liepin.

macOS 菜单栏启动器是原生 Swift AppKit 应用，会创建一个名为 `投递` 的状态栏入口，并在菜单中提供 BOSS 和猎聘操作。

- The menu can configure the run count before starting / 菜单中可以在启动前配置岗位数量。
- The menu exposes `Start BOSS` and `Start Liepin` actions / 菜单提供启动 BOSS 和启动猎聘的操作。
- The menu exposes stop, open logs, and quit actions / 菜单提供停止、打开日志和退出操作。
- The item title changes while a script is running / 脚本运行时状态栏标题会变化。
- A graphical flowchart is the primary status view and opens automatically when a run starts / 图形流程图是主要状态视图，并会在运行开始时自动打开。
- The menu keeps a single `Open Flowchart` entry instead of a nested state submenu / 菜单保留单个 `Open Flowchart` 入口，不再使用嵌套状态子菜单。
- Logs are written under `logs/` / 日志写入 `logs/`。
- The default run count is configurable with `MENU_RUNS`, default `5`, and can be changed from the menu / 默认轮数可通过 `MENU_RUNS` 配置，默认 `5`，也可以在菜单中修改。

## State Machine Visualization / 状态机可视化

Scripts emit structured status events while running. The menu bar app parses these events in real time and updates the graphical flowchart.

脚本运行时输出结构化状态事件。菜单栏 App 实时解析这些事件，并同步更新图形流程图。

Default states / 默认状态：

1. `prepare`: prepare device / 准备设备。
2. `verify_list`: verify the list before opening a job / 打开职位前校验列表。
3. `open_job`: open job detail / 打开职位。
4. `detect_button`: detect communication button / 识别沟通按钮。
5. `communicate`: tap new communication or skip existing conversation / 新沟通或跳过已沟通。
6. `return_list`: return to the list / 返回列表。
7. `verify_return`: confirm the script returned to the list / 确认已返回列表。
8. `scroll`: advance to the next job / 推进职位。
9. `run_complete`: finish the entire run / 完成整次运行。

Auxiliary event / 辅助事件：

- `iteration_done`: finish one iteration, then loop from `scroll` back to `verify_list` when more jobs remain / 完成单轮；如果还有岗位，则从 `scroll` 循环回 `verify_list`。

Flowchart markers / 流程图标记：

- `✓`: completed / 已完成。
- `▶`: current / 当前。
- `○`: pending / 未开始。
- `!`: failed or interrupted / 失败或中断。

## Configuration / 配置

Both scripts expose these environment variables.

两个脚本都会暴露以下环境变量。

- `RUNS`: number of loop iterations, default `1` / 循环次数，默认 `1`。
- `DELAY`: normal delay between iterations, default `1` second / 每轮间隔，默认 `1` 秒。
- `OPEN_DELAY`: wait after opening a job detail page / 打开职位详情后的等待时间。
- `POST_BUTTON_DELAY`: wait after tapping the communication button / 点击沟通按钮后的等待时间。
- `RETURN_DELAY`: wait between back taps / 返回点击之间的等待时间。
- `JOB_X`, `JOB_Y`: fallback job card tap point / 职位卡片兜底点击坐标。
- `BUTTON_X`, `BUTTON_Y`: fallback communication button tap point / 沟通按钮兜底点击坐标。
- `BACK_X`, `BACK_Y`: top-left app back button tap point / App 左上角返回按钮点击坐标。
- `SWIPE_X`, `SWIPE_START_Y`, `SWIPE_END_Y`, `SWIPE_MS`: fallback list scroll gesture / 列表兜底滑动手势配置。
- `SMART_SCROLL`: enable UI-verified one-card advancement, default `1` / 启用 UI 校验的单职位推进，默认 `1`。
- `PAGE_GUARD`: enable page and interruption checks, default `1` / 启用页面和中断检查，默认 `1`。
- `OCR_FALLBACK`: enable screenshot OCR fallback, default `1` / 启用截图 OCR 兜底，默认 `1`。
- `MENU_RUNS`: default run count used by the menu bar app, default `5` / 菜单栏 App 使用的默认轮数，默认 `5`。
- `SMART_SCROLL_MIN_STEPS`: minimum small swipes before accepting one-job advancement, default `2` / 接受单职位推进成功前至少短滑次数，默认 `2`。

Coordinate fallback remains available when UI detection fails.

当 UI 识别失败时，仍可使用坐标兜底。

## Safety And Error Handling / 安全和错误处理

- The scripts check that exactly one authorized ADB device is connected before running / 脚本启动前检查是否只有一台已授权的 ADB 设备连接。
- The scripts print all key coordinates, guard settings, and run counts before starting / 启动前打印关键坐标、守卫配置和循环次数。
- `RUNS` defaults to `1` for direct shell runs so the first execution is easy to verify / 直接命令行运行时 `RUNS` 默认是 `1`，方便先做单轮验证。
- Delays are intentionally kept between actions to reduce accidental rapid tapping / 动作之间保留延迟，降低误触和过快点击风险。
- Unexpected pages are detected before the next tap whenever possible / 尽可能在下一次点击前检测异常页面。
- Repeated blind recovery is avoided; the script stops after bounded recovery attempts / 避免反复盲目恢复；超过有限恢复次数后脚本停止。
- The user explicitly approved real communication/tap actions for testing / 用户已明确允许测试时真实点击沟通按钮。

## Test Plan / 测试计划

1. Run `adb devices -l` and verify the device state is `device` / 运行 `adb devices -l`，确认设备状态是 `device`。
2. Run syntax checks for all shell scripts / 对所有 shell 脚本运行语法检查。
3. Build the macOS menu bar app / 构建 macOS 菜单栏 App。
4. Start with BOSS on a job list page and execute `RUNS=1 ./boss_apply.sh` / 在 BOSS 职位列表页执行 `RUNS=1 ./boss_apply.sh`。
5. Confirm one job was opened, communication was tapped, the app returned to the list, and the list advanced by one job / 确认脚本打开了一个职位、点击了沟通、返回列表并推进一个职位。
6. Repeat with Liepin using `RUNS=1 ./liepin_apply.sh` / 在猎聘中用 `RUNS=1 ./liepin_apply.sh` 重复验证。
7. Verify the menu bar app opens one `投递` menu, can configure the run count, can start BOSS/Liepin scripts, and updates status visualization from dry-run state events / 验证菜单栏 App 只显示一个 `投递` 菜单，可以配置岗位数量，能启动 BOSS/猎聘脚本，并能通过 dry-run 状态事件更新可视化状态。