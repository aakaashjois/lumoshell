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

func resolveExecutablePath(_ command: String) -> String? {
    let fileManager = FileManager.default
    let expanded = (command as NSString).expandingTildeInPath
    if expanded.contains("/") {
        return fileManager.isExecutableFile(atPath: expanded) ? expanded : nil
    }

    let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
    for component in environmentPath.split(separator: ":") {
        let candidate = String(component) + "/" + expanded
        if fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }
    }

    return nil
}

func currentAppearanceMode() -> AppearanceMode {
    let app = NSApplication.shared
    let match = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
    switch match {
    case .some(.darkAqua):
        return .dark
    case .some(.aqua):
        return .light
    default:
        let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return style == "Dark" ? .dark : .light
    }
}

final class ApplyRunner {
    private let applyCommand: String
    private let quiet: Bool
    private let logger: AgentLogger
    private var lastRunAt: Date = .distantPast
    private let minInterval: TimeInterval = 0.25

    init(applyCommand: String, quiet: Bool, logger: AgentLogger) {
        self.applyCommand = applyCommand
        self.quiet = quiet
        self.logger = logger
    }

    func run() {
        let now = Date()
        if now.timeIntervalSince(lastRunAt) < minInterval {
            logger.log("skipping apply due to debounce window", level: .debug)
            return
        }
        lastRunAt = now

        let process = Process()
        process.executableURL = URL(fileURLWithPath: applyCommand)
        process.arguments = []

        if quiet {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        do {
            try process.run()
            logger.log("launched apply command '\(applyCommand)'", level: .info)
        } catch {
            logger.log("failed to execute \(applyCommand): \(error)", level: .error)
            if !quiet {
                fputs("lumoshell-appearance-sync-agent: failed to execute \(applyCommand): \(error)\n", stderr)
            }
        }
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
            fputs("lumoshell-appearance-sync-agent: failed to create log directory at \(directoryPath): \(error)\n", stderr)
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

final class AppearanceSyncAgent {
    private let applyRunner: ApplyRunner
    private let logger: AgentLogger
    private var appearanceObservation: NSKeyValueObservation?
    private var distributedThemeObserver: NSObjectProtocol?
    private var userDefaultsObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var sessionObserver: NSObjectProtocol?
    private var reconciliationTimer: Timer?
    private var lastMode: AppearanceMode?

    init(config: Config) {
        self.logger = AgentLogger(logFilePath: config.logFile)
        self.applyRunner = ApplyRunner(applyCommand: config.applyCommand, quiet: config.quiet, logger: logger)
    }

    func start() {
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.prohibited)
        logger.log("appearance sync agent started", level: .info)
        trackAndApply(force: true)

        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            self?.trackAndApply(force: false)
        }

        distributedThemeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.trackAndApply(force: false)
        }

        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.trackAndApply(force: false)
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.trackAndApply(force: false)
        }

        sessionObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.trackAndApply(force: false)
        }

        // Safety net: reconcile periodically in case macOS drops theme-change notifications.
        reconciliationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.trackAndApply(force: false)
        }

        RunLoop.main.run()
    }

    private func trackAndApply(force: Bool) {
        let mode = currentAppearanceMode()
        if !force, mode == lastMode {
            return
        }
        lastMode = mode
        if force {
            logger.log("applying profile for initial mode=\(mode.rawValue)", level: .info)
        } else {
            logger.log("detected appearance change, mode=\(mode.rawValue)", level: .info)
        }
        applyRunner.run()
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

              --apply-cmd <path>   Path to lumoshell-apply (default: lumoshell-apply)
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
guard let resolvedApplyCommand = resolveExecutablePath(config.applyCommand) else {
    fputs("lumoshell-appearance-sync-agent: could not resolve executable '\(config.applyCommand)' from PATH or absolute path\n", stderr)
    exit(1)
}

var resolvedConfig = config
resolvedConfig.applyCommand = resolvedApplyCommand
let agent = AppearanceSyncAgent(config: resolvedConfig)
agent.start()
