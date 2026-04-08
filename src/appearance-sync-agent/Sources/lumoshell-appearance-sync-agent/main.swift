import AppKit
import Foundation

enum AppearanceMode: String, Equatable {
    case light
    case dark
}

struct Config {
    var applyCommand: String = "lumoshell-apply"
    var quiet: Bool = false
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
    private var lastRunAt: Date = .distantPast
    private let minInterval: TimeInterval = 0.25

    init(applyCommand: String, quiet: Bool) {
        self.applyCommand = applyCommand
        self.quiet = quiet
    }

    func run(reason: String) {
        let now = Date()
        if now.timeIntervalSince(lastRunAt) < minInterval {
            return
        }
        lastRunAt = now

        let process = Process()
        process.executableURL = URL(fileURLWithPath: applyCommand)
        process.arguments = ["--reason", reason]

        if quiet {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        do {
            try process.run()
        } catch {
            if !quiet {
                fputs("lumoshell-appearance-sync-agent: failed to execute \(applyCommand): \(error)\n", stderr)
            }
        }
    }
}

final class AppearanceSyncAgent {
    private let applyRunner: ApplyRunner
    private var appearanceObservation: NSKeyValueObservation?
    private var distributedThemeObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var lastMode: AppearanceMode?

    init(config: Config) {
        self.applyRunner = ApplyRunner(applyCommand: config.applyCommand, quiet: config.quiet)
    }

    func start() {
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.prohibited)
        trackAndApply(reason: "startup", force: true)

        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            self?.trackAndApply(reason: "theme-change", force: false)
        }

        distributedThemeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.trackAndApply(reason: "theme-change", force: false)
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.trackAndApply(reason: "wake", force: false)
        }

        RunLoop.main.run()
    }

    private func trackAndApply(reason: String, force: Bool) {
        let mode = currentAppearanceMode()
        if !force, mode == lastMode {
            return
        }
        lastMode = mode
        applyRunner.run(reason: reason)
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
        case "-h", "--help":
            print("""
            Usage: lumoshell-appearance-sync-agent [options]

              --apply-cmd <path>   Path to lumoshell-apply (default: lumoshell-apply)
              --quiet              Reduce output
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
