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
    var events: [String] = []
}

final class FlowDiagramView: NSView {
    private let steps: [FlowStep]
    var snapshot: FlowSnapshot { didSet { needsDisplay = true } }

    init(steps: [FlowStep], snapshot: FlowSnapshot) {
        self.steps = steps
        self.snapshot = snapshot
        super.init(frame: NSRect(x: 0, y: 0, width: 820, height: 620))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let currentIndex = stepIndex(snapshot.currentStep)
        drawHeader()

        let rects = stepRects()
        drawConnectors(rects)
        drawLoopConnector(rects)

        for (index, step) in steps.enumerated() {
            guard let rect = rects[step.key] else { continue }
            colorForStep(index: index, currentIndex: currentIndex).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            NSColor.separatorColor.setStroke()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).stroke()
            drawText("\(markerForStep(index: index, currentIndex: currentIndex)) \(step.title)", in: rect.insetBy(dx: 10, dy: 18), size: 13, color: .labelColor, bold: index == currentIndex)
        }

        drawRecentEvents()
    }

    private func drawHeader() {
        let title = snapshot.total > 0 ? "\(displayAppName())  \(snapshot.iteration)/\(snapshot.total)" : displayAppName()
        let stepTitle = titleForStep(snapshot.currentStep)
        let detail = snapshot.failed ? "异常/停止：\(snapshot.message)" : "当前阶段：\(stepTitle) · \(snapshot.message)"
        drawText(title, in: NSRect(x: 28, y: 18, width: bounds.width - 56, height: 24), size: 17, color: .labelColor, bold: true, alignment: .left)
        drawText(detail, in: NSRect(x: 28, y: 44, width: bounds.width - 56, height: 22), size: 13, color: snapshot.failed ? .systemRed : .secondaryLabelColor, alignment: .left)
    }

    private func stepRects() -> [String: NSRect] {
        let boxWidth: CGFloat = 190
        let boxHeight: CGFloat = 58
        let columnGap: CGFloat = 70
        let rowGap: CGFloat = 44
        let startX: CGFloat = 56
        let startY: CGFloat = 92
        let positions: [String: (Int, Int)] = [
            "check_adb": (0, 0),
            "prepare": (0, 1),
            "verify_list": (1, 1),
            "open_job": (2, 1),
            "return_list": (0, 2),
            "communicate": (1, 2),
            "detect_button": (2, 2),
            "verify_return": (0, 3),
            "scroll": (1, 3),
            "run_complete": (2, 3)
        ]

        var rects: [String: NSRect] = [:]
        for (key, position) in positions {
            rects[key] = NSRect(
                x: startX + CGFloat(position.0) * (boxWidth + columnGap),
                y: startY + CGFloat(position.1) * (boxHeight + rowGap),
                width: boxWidth,
                height: boxHeight
            )
        }
        return rects
    }

    private func drawConnectors(_ rects: [String: NSRect]) {
        drawArrow(from: bottom(of: rects["check_adb"]), to: top(of: rects["prepare"]))
        drawArrow(from: right(of: rects["prepare"]), to: left(of: rects["verify_list"]))
        drawArrow(from: right(of: rects["verify_list"]), to: left(of: rects["open_job"]))
        drawArrow(from: bottom(of: rects["open_job"]), to: top(of: rects["detect_button"]))
        drawArrow(from: left(of: rects["detect_button"]), to: right(of: rects["communicate"]))
        drawArrow(from: left(of: rects["communicate"]), to: right(of: rects["return_list"]))
        drawArrow(from: bottom(of: rects["return_list"]), to: top(of: rects["verify_return"]))
        drawArrow(from: right(of: rects["verify_return"]), to: left(of: rects["scroll"]))
        drawArrow(from: right(of: rects["scroll"]), to: left(of: rects["run_complete"]))
    }

    private func drawLoopConnector(_ rects: [String: NSRect]) {
        guard let scroll = rects["scroll"], let verify = rects["verify_list"] else { return }
        let loopY = scroll.maxY + 22
        let loopX: CGFloat = 24
        let points = [
            NSPoint(x: scroll.midX, y: scroll.maxY + 4),
            NSPoint(x: scroll.midX, y: loopY),
            NSPoint(x: loopX, y: loopY),
            NSPoint(x: loopX, y: verify.midY),
            NSPoint(x: verify.minX - 8, y: verify.midY)
        ]
        drawArrow(points: points, dashed: true, color: .tertiaryLabelColor)
        drawText("下一个岗位 / next job", in: NSRect(x: loopX + 8, y: loopY - 18, width: 180, height: 18), size: 11, color: .secondaryLabelColor, alignment: .left)
    }

    private func right(of rect: NSRect?) -> NSPoint { NSPoint(x: rect?.maxX ?? 0, y: rect?.midY ?? 0) }
    private func left(of rect: NSRect?) -> NSPoint { NSPoint(x: rect?.minX ?? 0, y: rect?.midY ?? 0) }
    private func top(of rect: NSRect?) -> NSPoint { NSPoint(x: rect?.midX ?? 0, y: rect?.minY ?? 0) }
    private func bottom(of rect: NSRect?) -> NSPoint { NSPoint(x: rect?.midX ?? 0, y: rect?.maxY ?? 0) }

    private func drawArrow(from start: NSPoint, to end: NSPoint) {
        drawArrow(points: [start, end], dashed: false, color: .secondaryLabelColor)
    }

    private func drawArrow(points: [NSPoint], dashed: Bool, color: NSColor) {
        guard points.count >= 2 else { return }
        let path = NSBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() { path.line(to: point) }
        if dashed {
            var pattern: [CGFloat] = [5, 4]
            path.setLineDash(&pattern, count: pattern.count, phase: 0)
        }
        color.setStroke()
        path.lineWidth = dashed ? 1.0 : 1.2
        path.stroke()
        drawArrowHead(from: points[points.count - 2], to: points[points.count - 1], color: color)
    }

    private func drawArrowHead(from start: NSPoint, to end: NSPoint, color: NSColor) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 7
        let spread: CGFloat = .pi / 6
        let left = NSPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread))
        let right = NSPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread))
        let path = NSBezierPath()
        path.move(to: left)
        path.line(to: end)
        path.line(to: right)
        color.setStroke()
        path.lineWidth = 1.2
        path.stroke()
    }

    private func drawRecentEvents() {
        let titleRect = NSRect(x: 28, y: 488, width: bounds.width - 56, height: 20)
        drawText("最近状态 / Recent states", in: titleRect, size: 12, color: .secondaryLabelColor, bold: true, alignment: .left)
        let events = snapshot.events.suffix(4)
        if events.isEmpty {
            drawText("等待脚本状态事件 / Waiting for script state events", in: NSRect(x: 28, y: 514, width: bounds.width - 56, height: 20), size: 12, color: .tertiaryLabelColor, alignment: .left)
            return
        }
        for (offset, event) in events.enumerated() {
            drawText(event, in: NSRect(x: 28, y: 514 + CGFloat(offset) * 20, width: bounds.width - 56, height: 18), size: 12, color: .secondaryLabelColor, alignment: .left)
        }
    }

    private func stepIndex(_ key: String) -> Int {
        steps.firstIndex { $0.key == key } ?? -1
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
        if snapshot.currentStep == "run_complete" && index == currentIndex { return "✓" }
        if index == currentIndex { return "▶" }
        return "○"
    }

    private func colorForStep(index: Int, currentIndex: Int) -> NSColor {
        if snapshot.failed && index == max(currentIndex, 0) { return NSColor.systemRed.withAlphaComponent(0.22) }
        if snapshot.currentStep == "run_complete" && index <= currentIndex { return NSColor.systemGreen.withAlphaComponent(0.18) }
        if index == currentIndex { return NSColor.systemBlue.withAlphaComponent(0.20) }
        if currentIndex >= 0 && index < currentIndex { return NSColor.systemGreen.withAlphaComponent(0.18) }
        return NSColor.controlBackgroundColor
    }

    private func titleForStep(_ key: String) -> String {
        if let step = steps.first(where: { $0.key == key }) { return step.title }
        if key == "iteration_done" { return "单轮完成" }
        if key == "failed" { return "异常/停止" }
        return "空闲"
    }

    private func drawText(_ text: String, in rect: NSRect, size: CGFloat, color: NSColor, bold: Bool = false, alignment: NSTextAlignment = .center) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
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
        FlowStep(key: "check_adb", title: "检测ADB连接"),
        FlowStep(key: "prepare", title: "准备设备"),
        FlowStep(key: "verify_list", title: "校验列表"),
        FlowStep(key: "open_job", title: "打开职位"),
        FlowStep(key: "detect_button", title: "识别按钮"),
        FlowStep(key: "communicate", title: "沟通/跳过"),
        FlowStep(key: "return_list", title: "返回列表"),
        FlowStep(key: "verify_return", title: "确认返回"),
        FlowStep(key: "scroll", title: "推进职位"),
        FlowStep(key: "run_complete", title: "运行完成")
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

        menu.addItem(disabledItem(statusTitle()))
        menu.addItem(disabledItem(snapshot.message))

        let flowItem = NSMenuItem(title: "Open Flowchart / 打开图形流程图", action: #selector(showFlowPanel), keyEquivalent: "f")
        flowItem.target = self
        menu.addItem(flowItem)
        menu.addItem(NSMenuItem.separator())

        let countRoot = NSMenuItem(title: "Run count: \(runCount) / 岗位数：\(runCount)", action: nil, keyEquivalent: "")
        countRoot.submenu = buildCountMenu()
        menu.addItem(countRoot)
        menu.addItem(NSMenuItem.separator())

        addStartItem(menu, title: "Start BOSS (\(runCount)) / 启动 BOSS（\(runCount)）", key: "b", action: #selector(startBoss))
        addStartItem(menu, title: "Start Liepin (\(runCount)) / 启动猎聘（\(runCount)）", key: "l", action: #selector(startLiepin))

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

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func statusTitle() -> String {
        if !snapshot.running && snapshot.iteration == 0 { return "Idle / 空闲" }
        return "\(shortAppName(snapshot.appName))  \(snapshot.iteration)/\(snapshot.total) · \(titleForStep(snapshot.currentStep))"
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
        appendEvent(step: "failed", message: snapshot.message)
        statusItem.button?.title = "投递"
        refreshUI()
    }

    @objc private func showFlowPanel() { presentFlowPanel(activate: true) }

    private func presentFlowPanel(activate: Bool) {
        if flowPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 820, height: 620), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = "投递流程 / Apply Flow"
            panel.isReleasedWhenClosed = false
            let view = FlowDiagramView(steps: steps, snapshot: snapshot)
            panel.contentView = view
            flowPanel = panel
            flowView = view
        }
        flowPanel?.center()
        flowPanel?.makeKeyAndOrderFront(nil)
        if activate { NSApp.activate(ignoringOtherApps: true) }
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

        snapshot = FlowSnapshot(appName: label, iteration: 0, total: runCount, currentStep: "check_adb", message: "Starting / 启动中", running: true, failed: false, events: [])
        appendEvent(step: "check_adb", message: snapshot.message)
        outputBuffer = ""
        refreshUI()
        presentFlowPanel(activate: true)

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
                if success {
                    self.snapshot.currentStep = "run_complete"
                    self.snapshot.message = "Run complete / 运行完成"
                    self.appendEvent(step: "run_complete", message: self.snapshot.message)
                } else {
                    self.snapshot.message = "Failed with exit \(finishedProcess.terminationStatus) / 异常退出"
                    self.appendEvent(step: "failed", message: self.snapshot.message)
                }
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
            appendEvent(step: "failed", message: snapshot.message)
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
        let step = String(parts[4])
        snapshot.message = String(parts[5])
        if step == "failed" {
            snapshot.failed = true
        } else if step == "iteration_done" {
            snapshot.failed = false
        } else if step == "run_complete" {
            snapshot.currentStep = step
            snapshot.running = false
            snapshot.failed = false
        } else {
            snapshot.currentStep = step
            snapshot.failed = false
        }
        appendEvent(step: step, message: snapshot.message)
        snapshot.running = process != nil || snapshot.running
        statusItem.button?.title = "\(shortAppName(snapshot.appName))... \(snapshot.iteration)/\(snapshot.total)"
        refreshUI()
    }

    private func appendEvent(step: String, message: String) {
        let count = snapshot.total > 0 ? "\(snapshot.iteration)/\(snapshot.total)" : "--"
        let entry = "\(count) \(titleForStep(step)): \(message)"
        if snapshot.events.last == entry { return }
        snapshot.events.append(entry)
        if snapshot.events.count > 8 {
            snapshot.events.removeFirst(snapshot.events.count - 8)
        }
    }

    private func titleForStep(_ key: String) -> String {
        if let step = steps.first(where: { $0.key == key }) { return step.title }
        if key == "iteration_done" { return "单轮完成" }
        if key == "failed" { return "异常/停止" }
        return "空闲"
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