import AppKit

final class JobAutopilotMenu: NSObject, NSMenuDelegate {
    private let rootURL: URL
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let runCountOptions = [1, 3, 5, 10, 20]
    private var runCount: Int
    private var process: Process?

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.runCount = Int(ProcessInfo.processInfo.environment["MENU_RUNS"] ?? "5") ?? 5
        super.init()
    }

    func install() {
        statusItem.button?.title = "投递"
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let countMenu = NSMenu()
        for count in runCountOptions {
            let item = NSMenuItem(title: "\(count) jobs / \(count) 个岗位", action: #selector(setRunCount(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = count
            item.state = count == runCount ? .on : .off
            countMenu.addItem(item)
        }
        countMenu.addItem(NSMenuItem.separator())
        let customItem = NSMenuItem(title: "Custom... / 自定义...", action: #selector(setCustomRunCount), keyEquivalent: "")
        customItem.target = self
        countMenu.addItem(customItem)

        let countRoot = NSMenuItem(title: "Run count: \(runCount) / 岗位数：\(runCount)", action: nil, keyEquivalent: "")
        countRoot.submenu = countMenu
        menu.addItem(countRoot)
        menu.addItem(NSMenuItem.separator())

        let bossItem = NSMenuItem(title: "Start BOSS (\(runCount)) / 启动 BOSS（\(runCount)）", action: #selector(startBoss), keyEquivalent: "b")
        bossItem.target = self
        bossItem.isEnabled = process == nil
        menu.addItem(bossItem)

        let liepinItem = NSMenuItem(title: "Start Liepin (\(runCount)) / 启动猎聘（\(runCount)）", action: #selector(startLiepin), keyEquivalent: "l")
        liepinItem.target = self
        liepinItem.isEnabled = process == nil
        menu.addItem(liepinItem)

        let stopItem = NSMenuItem(title: "Stop Running Script / 停止当前脚本", action: #selector(stopRunningScript), keyEquivalent: "s")
        stopItem.target = self
        stopItem.isEnabled = process != nil
        menu.addItem(stopItem)

        menu.addItem(NSMenuItem.separator())

        let logsItem = NSMenuItem(title: "Open Logs / 打开日志", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        let quitItem = NSMenuItem(title: "Quit / 退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        statusItem.menu = buildMenu()
    }

    @objc private func setRunCount(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        runCount = value
        statusItem.menu = buildMenu()
    }

    @objc private func setCustomRunCount() {
        let alert = NSAlert()
        alert.messageText = "Run count / 岗位数"
        alert.informativeText = "Enter how many jobs to process this run. / 输入本次要处理的岗位数量。"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = String(runCount)
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn, let value = Int(field.stringValue), value > 0 {
            runCount = value
            statusItem.menu = buildMenu()
        }
    }

    @objc private func startBoss() {
        start(scriptName: "boss_apply.sh", label: "BOSS")
    }

    @objc private func startLiepin() {
        start(scriptName: "liepin_apply.sh", label: "猎聘")
    }

    @objc private func stopRunningScript() {
        process?.terminate()
        process = nil
        statusItem.button?.title = "投递"
        statusItem.menu = buildMenu()
    }

    @objc private func openLogs() {
        let logDir = rootURL.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(logDir)
    }

    @objc private func quit() {
        process?.terminate()
        NSApp.terminate(nil)
    }

    private func start(scriptName: String, label: String) {
        guard process == nil else { return }

        let scriptURL = rootURL.appendingPathComponent(scriptName)
        let logDir = rootURL.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let logURL = logDir.appendingPathComponent("\(scriptName)-\(stamp).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        guard let handle = try? FileHandle(forWritingTo: logURL) else {
            statusItem.button?.title = "投递!"
            return
        }

        var environment = ProcessInfo.processInfo.environment
        environment["RUNS"] = String(runCount)
        environment["MENU_LAUNCHED"] = "1"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        let process = Process()
        process.executableURL = scriptURL
        process.currentDirectoryURL = rootURL
        process.environment = environment
        process.standardOutput = handle
        process.standardError = handle
        process.terminationHandler = { [weak self, handle] finishedProcess in
            try? handle.close()
            DispatchQueue.main.async {
                guard let self else { return }
                self.process = nil
                let success = finishedProcess.terminationStatus == 0
                self.statusItem.button?.title = success ? "投递" : "投递!"
                self.statusItem.menu = self.buildMenu()
                if !success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if self.process == nil {
                            self.statusItem.button?.title = "投递"
                        }
                    }
                }
            }
        }

        do {
            try process.run()
            self.process = process
            statusItem.button?.title = "\(label)..."
            statusItem.menu = buildMenu()
        } catch {
            try? handle.close()
            statusItem.button?.title = "投递!"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menu: JobAutopilotMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let menu = JobAutopilotMenu(rootURL: resolveRootURL())
        menu.install()
        self.menu = menu
    }

    private func resolveRootURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["ADB_JOB_AUTOPILOT_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()