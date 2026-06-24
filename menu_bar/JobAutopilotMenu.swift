import AppKit

final class ScriptRunner: NSObject {
    private let title: String
    private let scriptName: String
    private let rootURL: URL
    private var statusItem: NSStatusItem?
    private var process: Process?

    init(title: String, scriptName: String, rootURL: URL) {
        self.title = title
        self.scriptName = scriptName
        self.rootURL = rootURL
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = title
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func toggle() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            NSApp.terminate(nil)
            return
        }

        if let process, process.isRunning {
            process.terminate()
            statusItem?.button?.title = title
            self.process = nil
            return
        }
        start()
    }

    private func start() {
        let scriptURL = rootURL.appendingPathComponent(scriptName)
        let logDir = rootURL.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let logURL = logDir.appendingPathComponent("\(scriptName)-\(stamp).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        guard let handle = try? FileHandle(forWritingTo: logURL) else {
            statusItem?.button?.title = "\(title)!"
            return
        }

        var environment = ProcessInfo.processInfo.environment
        environment["RUNS"] = environment["MENU_RUNS"] ?? "5"
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
                self.statusItem?.button?.title = success ? self.title : "\(self.title)!"
                if !success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if self.process == nil {
                            self.statusItem?.button?.title = self.title
                        }
                    }
                }
            }
        }

        do {
            try process.run()
            self.process = process
            statusItem?.button?.title = "\(title)..."
        } catch {
            try? handle.close()
            statusItem?.button?.title = "\(title)!"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runners: [ScriptRunner] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let rootURL = resolveRootURL()
        runners = [
            ScriptRunner(title: "BOSS", scriptName: "boss_apply.sh", rootURL: rootURL),
            ScriptRunner(title: "猎聘", scriptName: "liepin_apply.sh", rootURL: rootURL)
        ]
        runners.forEach { $0.install() }
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