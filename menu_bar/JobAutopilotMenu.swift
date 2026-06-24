import AppKit

struct FlowStep {
    let key: String
    let title: String
}

struct FlowSnapshot {
    var appName = "Idle"
    var iteration = 0
    var total = 0
    var currentStep = "idle"
    var message = "Idle / 空闲"
    var running = false
    var failed = false
}

final class FlowDiagramView: NSView {
    private let steps: [FlowStep]
    var snapshot: FlowSnapshot { didSet { needsDisplay = true } }

    init(steps: [FlowStep], snapshot: FlowSnapshot) {
        self.steps = steps
        self.snapshot = snapshot
        super.init(frame: NSRect(x: 0, y: 0, width: 760, height: 300))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let currentIndex = steps.firstIndex { $0.key == snapshot.currentStep } ?? -1
        drawText("\(displayAppName())  \(snapshot.iteration)/\(snapshot.total)  \(snapshot.message)", in: NSRect(x: 24, y: 18, width: bounds.width - 48, height: 24), size: 15, color: .labelColor, bold: true)

        let boxWidth: CGFloat = 160
        let boxHeight: CGFloat = 58
        let xGap: CGFloat = 24
        let yGap: CGFloat = 54
        let startX: CGFloat = 24
        let startY: CGFloat = 68

        for (index, step) in steps.enumerated() {
            let rect = NSRect(
                x: startX + CGFloat(index % 4) * (boxWidth + xGap),
                y: startY + CGFloat(index / 4) * (boxHeight + yGap),
                width: boxWidth,
                height: boxHeight
            )
            colorForStep(index: index, currentIndex: currentIndex).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            NSColor.separatorColor.setStroke()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).stroke()
            drawText("\(markerForStep(index: index, currentIndex: currentIndex)) \(step.title)", in: rect.insetBy(dx: 10, dy: 18), size: 13, color: .labelColor, bold: index == currentIndex)
            drawArrowIfNeeded(index: index, rect: rect, xGap: xGap)
        }
    }

    private func displayAppName() -> String {
        if snapshot.appName.contains("BOSS") { return "BOSS" }
        if snapshot.appName.contains("Liepin") { return "猎聘" }
        return snapshot.appName
    }

    private func markerForStep(index: Int, currentIndex: Int) -> String {
        if snapshot.failed { return index == max(currentIndex, 0) ? "!" : "○" }
        if currentIndex < 0 { return "○" }
        if index < currentIndex { return "✓" }
        if index == currentIndex { return "▶" }
        return "○"
    }

    private func colorForStep(index: Int, currentIndex: Int) -> NSColor {
        if snapshot.failed && index == max(currentIndex, 0) { return NSColor.systemRed.withAlphaComponent(0.22) }
        if index == currentIndex { return NSColor.systemBlue.withAlphaComponent(0.20) }
        if currentIndex >= 0 && index < currentIndex { return NSColor.systemGreen.withAlphaComponent(0.18) }
        return NSColor.controlBackgroundColor
    }

    private func drawArrowIfNeeded(index: Int, rect: NSRect, xGap: CGFloat) {
        if index == steps.count - 1 || index % 4 == 3 { return }
        let start = NSPoint(x: rect.maxX + 5, y: rect.midY)
        let end = NSPoint(x: rect.maxX + xGap - 5, y: rect.midY)
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.move(to: NSPoint(x: end.x - 5, y: end.y - 4))
        path.line(to: end)
        path.line(to: NSPoint(x: end.x - 5, y: end.y + 4))
        NSColor.secondaryLabelColor.setStroke()
        path.lineWidth = 1.2
        path.stroke()
    }

    private func drawText(_ text: String, in rect: NSRect, size: CGFloat, color: NSColor, bold: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        NSString(string: text).draw(in: rect, withAttributes: attributes)
    }
}

final class JobAutopilotMenu: NSObject, NSMenuDelegate {
    private let rootURL: URL
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let runCountOptions = [1, 3, 5, 10, 20]
    private let steps = [
        FlowStep(key: "prepare", title: "准备设备"),
        FlowStep(key: "guard", title: "校验页面"),
        FlowStep(key: "open_job", title: "打开职位"),
        FlowStep(key: "detect_button", title: "识别按钮"),
        FlowStep(key: "communicate", title: "沟通/跳过"),
        FlowStep(key: "return_list", title: "返回列表"),
        FlowStep(key: "scroll", title: "推进职位"),
        FlowStep(key: "complete", title: "完成")
    ]
    private var runCount: Int
    private var process: Process?
    private var outputBuffer = ""
    private var snapshot = FlowSnapshot()
    private var flowPanel: NSPanel?
    private var flowView: FlowDiagramView?

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

        let countRoot = NSMenuItem(title: "Run count: \(runCount) / 岗位数：\(runCount)", action: nil, keyEquivalent: "")
        countRoot.submenu = buildCountMenu()
        menu.addItem(countRoot)

        let statusRoot = NSMenuItem(title: "Status / 当前流程", action: nil, keyEquivalent: "")
        statusRoot.submenu = buildStatusMenu()
        menu.addItem(statusRoot)
        menu.addItem(NSMenuItem.separator())

        addStartItem(menu, title: "Start BOSS (\(runCount)) / 启动 BOSS（\(runCount)）", key: "b", action: #selector(startBoss))
        addStartItem(menu, title: "Start Liepin (\(runCount)) / 启动猎聘（\(runCount)）", key: "l", action: #selector(startLiepin))

        let stopItem = NSMenuItem(title: "Stop Running Script / 停止当前脚本", action: #selector(stopRunningScript), keyEquivalent: "s")
        stopItem.target = self
        stopItem.isEnabled = process != nil
        menu.addItem(stopItem)
        menu.addItem(NSMenuItem.separator())

        let panelItem = NSMenuItem(title: "Show Flow Panel / 显示流程面板", action: #selector(showFlowPanel), keyEquivalent: "f")
        panelItem.target = self
        menu.addItem(panelItem)

        let logsItem = NSMenuItem(title: "Open Logs / 打开日志", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        let quitItem = NSMenuItem(title: "Quit / 退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    private func addStartItem(_ menu: NSMenu, title: String, key: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = process == nil
        menu.addItem(item)
    }

    private func buildCountMenu() -> NSMenu {
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
        return countMenu
    }

    private func buildStatusMenu() -> NSMenu {
        let statusMenu = NSMenu()
        statusMenu.addItem(disabledItem(statusTitle()))
        statusMenu.addItem(disabledItem(snapshot.message))
        statusMenu.addItem(NSMenuItem.separator())
        let currentIndex = steps.firstIndex { $0.key == snapshot.currentStep } ?? -1
        for (index, step) in steps.enumerated() {
            statusMenu.addItem(disabledItem("\(markerForStep(index: index, currentIndex: currentIndex)) \(step.title)"))
        }
        return statusMenu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func statusTitle() -> String {
        if !snapshot.running && snapshot.iteration == 0 { return "Idle / 空闲" }
        return "\(shortAppName(snapshot.appName))  \(snapshot.iteration)/\(snapshot.total)"
    }

    private func markerForStep(index: Int, currentIndex: Int) -> String {
        if snapshot.failed { return index == max(currentIndex, 0) ? "!" : "○" }
        if currentIndex < 0 { return "○" }
        if index < currentIndex { return "✓" }
        if index == currentIndex { return "▶" }
        return "○"
    }

    private func shortAppName(_ appName: String) -> String {
        if appName.contains("BOSS") { return "BOSS" }
        if appName.contains("Liepin") { return "猎聘" }
        return appName
    }

    func menuNeedsUpdate(_ menu: NSMenu) { statusItem.menu = buildMenu() }

    @objc private func setRunCount(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        runCount = value
        refreshUI()
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
            refreshUI()
        }
    }

    @objc private func startBoss() { start(scriptName: "boss_apply.sh", label: "BOSS") }
    @objc private func startLiepin() { start(scriptName: "liepin_apply.sh", label: "猎聘") }

    @objc private func stopRunningScript() {
        process?.terminate()
        process = nil
        snapshot.running = false
        snapshot.failed = true
        snapshot.message = "Stopped by user / 用户停止"
        statusItem.button?.title = "投递"
        refreshUI()
    }

    @objc private func showFlowPanel() {
        if flowPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 760, height: 300), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = "投递流程 / Apply Flow"
            panel.isReleasedWhenClosed = false
            let view = FlowDiagramView(steps: steps, snapshot: snapshot)
            panel.contentView = view
            flowPanel = panel
            flowView = view
        }
        flowPanel?.center()
        flowPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        guard let logHandle = try? FileHandle(forWritingTo: logURL) else {
            statusItem.button?.title = "投递!"
            return
        }

        snapshot = FlowSnapshot(appName: label, iteration: 0, total: runCount, currentStep: "prepare", message: "Starting / 启动中", running: true, failed: false)
        outputBuffer = ""
        refreshUI()

        var environment = ProcessInfo.processInfo.environment
        environment["RUNS"] = String(runCount)
        environment["MENU_LAUNCHED"] = "1"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        let pipe = Pipe()
        let process = Process()
        process.executableURL = scriptURL
        process.currentDirectoryURL = rootURL
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self, logHandle] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            logHandle.write(data)
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { self?.consumeOutput(text) }
            }
        }
        process.terminationHandler = { [weak self, logHandle, pipe] finishedProcess in
            pipe.fileHandleForReading.readabilityHandler = nil
            try? logHandle.close()
            DispatchQueue.main.async {
                guard let self else { return }
                self.process = nil
                let success = finishedProcess.terminationStatus == 0
                self.snapshot.running = false
                self.snapshot.failed = !success
                self.snapshot.currentStep = success ? "complete" : "failed"
                self.snapshot.message = success ? "Run complete / 运行完成" : "Failed with exit \(finishedProcess.terminationStatus) / 异常退出"
                self.statusItem.button?.title = success ? "投递" : "投递!"
                self.refreshUI()
            }
        }

        do {
            try process.run()
            self.process = process
            statusItem.button?.title = "\(label)..."
            refreshUI()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            try? logHandle.close()
            snapshot.running = false
            snapshot.failed = true
            snapshot.message = "Could not start script / 无法启动脚本"
            statusItem.button?.title = "投递!"
            refreshUI()
        }
    }

    private func consumeOutput(_ text: String) {
        outputBuffer += text
        while let range = outputBuffer.range(of: "\n") {
            let line = String(outputBuffer[..<range.lowerBound])
            outputBuffer = String(outputBuffer[range.upperBound...])
            parseStateLine(line)
        }
    }

    private func parseStateLine(_ line: String) {
        guard line.hasPrefix("STATE|") else { return }
        let parts = line.split(separator: "|", maxSplits: 5, omittingEmptySubsequences: false)
        guard parts.count >= 6 else { return }
        snapshot.appName = String(parts[1])
        snapshot.iteration = Int(parts[2]) ?? snapshot.iteration
        snapshot.total = Int(parts[3]) ?? snapshot.total
        snapshot.currentStep = String(parts[4])
        snapshot.message = String(parts[5])
        snapshot.failed = snapshot.currentStep == "failed"
        snapshot.running = process != nil
        statusItem.button?.title = "\(shortAppName(snapshot.appName))... \(snapshot.iteration)/\(snapshot.total)"
        refreshUI()
    }

    private func refreshUI() {
        statusItem.menu = buildMenu()
        flowView?.snapshot = snapshot
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