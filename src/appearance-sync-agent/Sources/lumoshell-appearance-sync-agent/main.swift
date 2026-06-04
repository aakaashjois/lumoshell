import AppKit
import Foundation

enum AppearanceMode: String, Equatable {
    case light
    case dark
}

struct Config {
    var applyCommand: String = "lumoshell-apply"
    var quiet: Bool = false
    var logFile: String = ("~/Library/Logs/lumoshell/appearance-sync-agent.log" as NSString).expandingTildeInPath
}

func currentAppearanceMode() -> AppearanceMode {
    // We use UserDefaults because it updates synchronously with the Distributed Notification.
    // AppKit's effectiveAppearance updates asynchronously and can cause a race condition
    // where it still returns the old mode, causing the agent to silently drop the event.
    let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    return isDark ? .dark : .light
}

final class ApplyRunner {
    private let logger: AgentLogger
    private let quiet: Bool
    private var lastRunAt: Date = .distantPast
    private let minInterval: TimeInterval = 0.25
    private let profileStoreDomain = "com.user.lumoshell"
    private let terminalDomain = "com.apple.Terminal"
    private let lightDefaultProfile = "Basic"
    private let darkDefaultProfile = "Pro"

    init(quiet: Bool, logger: AgentLogger) {
        self.quiet = quiet
        self.logger = logger
    }

    func run(trigger: String, mode: AppearanceMode) {
        let now = Date()
        if now.timeIntervalSince(lastRunAt) < minInterval {
            logger.log("trigger=\(trigger) skipping apply due to debounce window", level: .debug)
            return
        }
        lastRunAt = now

        let profile = resolveProfile(mode: mode)
        applyTerminalDefaults(profile: profile)
        applyOpenTabs(profile: profile)
        logger.log("trigger=\(trigger) mode=\(mode.rawValue) applied profile='\(profile)'", level: .info)
    }

    private func resolveProfile(mode: AppearanceMode) -> String {
        let profileStore = UserDefaults(suiteName: profileStoreDomain)
        let key = mode == .dark ? "DarkProfile" : "LightProfile"
        if let stored = profileStore?.string(forKey: key), !stored.isEmpty {
            return stored
        }
        return mode == .dark ? darkDefaultProfile : lightDefaultProfile
    }

    private func applyTerminalDefaults(profile: String) {
        guard let terminalDefaults = UserDefaults(suiteName: terminalDomain) else {
            logger.log("failed to open Terminal defaults domain", level: .error)
            return
        }
        terminalDefaults.set(profile, forKey: "Default Window Settings")
        terminalDefaults.set(profile, forKey: "Startup Window Settings")
        terminalDefaults.synchronize()
    }

    private func applyOpenTabs(profile: String) {
        guard isTerminalRunning() else {
            return
        }

        let escapedProfile = profile
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let scriptSource = """
        set targetProfile to "\(escapedProfile)"
        with timeout of 3 seconds
          tell application "Terminal"
            if (count of windows) > 0 then
              set current settings of tabs of windows to settings set targetProfile
            end if
            set default settings to settings set targetProfile
            set startup settings to settings set targetProfile
          end tell
        end timeout
        """

        guard let appleScript = NSAppleScript(source: scriptSource) else {
            logger.log("failed to compile NSAppleScript", level: .error)
            return
        }

        var errorDict: NSDictionary?
        appleScript.executeAndReturnError(&errorDict)

        if let error = errorDict {
            let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "unknown NSAppleScript error"
            let errorCode = error[NSAppleScript.errorNumber] as? Int ?? -1
            logger.log("open-tab apply failed with status=\(errorCode): \(errorMsg)", level: .error)
        }
    }

    private func isTerminalRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Terminal" }
    }
}

final class AgentLogger {
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case error = "ERROR"
    }

    private let logFilePath: String
    private let retentionInterval: TimeInterval = 24 * 60 * 60
    private let pruneInterval: TimeInterval = 5 * 60
    private var lastPrunedAt: Date = .distantPast
    private let formatter: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter
    }()

    init(logFilePath: String) {
        self.logFilePath = (logFilePath as NSString).expandingTildeInPath
        ensureLogDirectory()
    }

    func log(_ message: String, level: Level) {
        pruneIfNeeded()
        let timestamp = formatter.string(from: Date())
        appendLine("\(timestamp) [\(level.rawValue)] \(message)")
    }

    private func ensureLogDirectory() {
        let directoryPath = (logFilePath as NSString).deletingLastPathComponent
        if directoryPath.isEmpty {
            return
        }
        do {
            try FileManager.default.createDirectory(
                atPath: directoryPath,
                withIntermediateDirectories: true
            )
        } catch {
            fputs(
                "lumoshell-appearance-sync-agent: failed to create log directory at \(directoryPath): \(error)\n",
                stderr
            )
        }
    }

    private func appendLine(_ line: String) {
        let payload = line + "\n"
        guard let data = payload.data(using: .utf8) else {
            return
        }
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logFilePath) {
            fileManager.createFile(atPath: logFilePath, contents: nil)
        }
        do {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: logFilePath))
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            fputs("lumoshell-appearance-sync-agent: failed to write log file at \(logFilePath): \(error)\n", stderr)
        }
    }

    private func pruneIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastPrunedAt) < pruneInterval {
            return
        }
        lastPrunedAt = now
        prune(now: now)
    }

    private func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-retentionInterval)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: logFilePath)),
              let content = String(data: data, encoding: .utf8) else {
            return
        }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var kept: [String] = []
        kept.reserveCapacity(lines.count)

        for line in lines {
            let row = String(line)
            if row.isEmpty {
                continue
            }
            guard let firstToken = row.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first,
                  let timestamp = formatter.date(from: String(firstToken)) else {
                continue
            }
            if timestamp >= cutoff {
                kept.append(row)
            }
        }

        let rewritten = kept.joined(separator: "\n")
        let finalContent = rewritten.isEmpty ? "" : rewritten + "\n"
        try? finalContent.write(toFile: logFilePath, atomically: true, encoding: .utf8)
    }
}

final class AppearanceSyncAgent: NSObject, NSApplicationDelegate {
    private let applyRunner: ApplyRunner
    private let logger: AgentLogger
    private var lastMode: AppearanceMode?
    private var themeObserver: NSObjectProtocol?

    init(config: Config) {
        self.logger = AgentLogger(logFilePath: config.logFile)
        self.applyRunner = ApplyRunner(quiet: config.quiet, logger: self.logger)
        super.init()
        if !config.applyCommand.isEmpty && config.applyCommand != "lumoshell-apply" {
            logger.log("ignoring --apply-cmd in swift-native apply mode", level: .debug)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.log("appearance sync agent started", level: .info)
        trackAndApply(trigger: "startup", force: true)

        let themeNotification = Notification.Name("AppleInterfaceThemeChangedNotification")
        themeObserver = DistributedNotificationCenter.default().addObserver(
            forName: themeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.trackAndApply(trigger: "AppleInterfaceThemeChangedNotification", force: false)
        }
    }

    func start() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.delegate = self
        app.run()
    }

    private func trackAndApply(trigger: String, force: Bool) {
        let mode = currentAppearanceMode()
        if !force, mode == lastMode {
            return
        }
        lastMode = mode
        applyRunner.run(trigger: trigger, mode: mode)
    }
}

func parseArgs(arguments: [String]) -> Config {
    var config = Config()
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--apply-cmd":
            guard index + 1 < arguments.count else {
                fputs("--apply-cmd requires a value\n", stderr)
                exit(1)
            }
            config.applyCommand = arguments[index + 1]
            index += 2
        case "--quiet":
            config.quiet = true
            index += 1
        case "--log-file":
            guard index + 1 < arguments.count else {
                fputs("--log-file requires a value\n", stderr)
                exit(1)
            }
            config.logFile = (arguments[index + 1] as NSString).expandingTildeInPath
            index += 2
        case "-h", "--help":
            print("""
            Usage: lumoshell-appearance-sync-agent [options]

              --apply-cmd <path>   Deprecated in swift-native apply mode
              --quiet              Reduce output
              --log-file <path>    Path for sync-agent log file
            """)
            exit(0)
        default:
            fputs("Unknown argument: \(argument)\n", stderr)
            exit(1)
        }
    }

    return config
}

func parseArgs() -> Config {
    parseArgs(arguments: Array(CommandLine.arguments.dropFirst()))
}

let config = parseArgs()
let agent = AppearanceSyncAgent(config: config)
agent.start()
