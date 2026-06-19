import AppKit
import Foundation
import os

struct Config {
    var quiet: Bool = false
    var applyOnly: Bool = false
    var applyNewSession: Bool = false
    var dryRun: Bool = false
    var verbose: Bool = false
    var listProfiles: Bool = false
}

extension String {
    func escapedForAppleScript() -> String {
        return self.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

func isDarkAppearance() -> Bool {
    return NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
}

final class ApplyRunner {
    private let logger: Logger
    private let quiet: Bool
    private let verbose: Bool
    private let isManualApply: Bool
    private var lastRunAt: Date = .distantPast
    private let minInterval: TimeInterval = 0.25

    init(quiet: Bool, verbose: Bool, isManualApply: Bool, logger: Logger) {
        self.quiet = quiet
        self.verbose = verbose
        self.isManualApply = isManualApply
        self.logger = logger
    }

    func run(trigger: String, isDark: Bool, newSession: Bool = false, dryRun: Bool = false) {
        let now = Date()
        if !isManualApply && now.timeIntervalSince(lastRunAt) < minInterval {
            logger.info("trigger=\(trigger, privacy: .public) skipping apply due to debounce window")
            return
        }
        lastRunAt = now

        let profile = resolveProfile(isDark: isDark)

        if dryRun {
            print("mode=\(isDark ? "dark" : "light")")
            print("profile=\(profile)")
            if newSession {
                print("action=defaults+active-tab-best-effort")
            } else {
                print("action=defaults+all-open-tabs-best-effort")
            }
            return
        }

        if verbose && isManualApply {
            print("lumoshell-apply: mode=\(isDark ? "dark" : "light") profile=\(profile)")
        }

        applyTerminalDefaults(profile: profile)
        
        if isTerminalRunning() {
            let success = newSession ? applyToActiveSession(profile: profile) : applyToAllSessions(profile: profile)
            if !success {
                if isManualApply {
                    let fallbackMsg = newSession ? "applied defaults only for new session" : "kept defaults-only mode"
                    fputs("lumoshell warning: Automation permission not available; \(fallbackMsg).\n", stderr)
                }
                logger.error("open-tab apply failed: automation permission not available")
            }
        }
        
        logger.info("trigger=\(trigger, privacy: .public) mode=\(isDark ? "dark" : "light", privacy: .public) applied profile='\(profile, privacy: .public)'")
    }

    private func resolveProfile(isDark: Bool) -> String {
        let defaultsKey = isDark ? "DarkProfile" : "LightProfile"
        let store = UserDefaults(suiteName: "com.user.lumoshell")
        if let stored = store?.string(forKey: defaultsKey), !stored.isEmpty {
            return stored
        }
        return isDark ? "Pro" : "Basic"
    }

    private func applyTerminalDefaults(profile: String) {
        guard let defaults = UserDefaults(suiteName: "com.apple.Terminal") else {
            logger.error("failed to open Terminal defaults domain")
            return
        }
        defaults.set(profile, forKey: "Default Window Settings")
        defaults.set(profile, forKey: "Startup Window Settings")
        defaults.synchronize()
    }

    private func isTerminalRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Terminal" }
    }

    private func applyToActiveSession(profile: String) -> Bool {
        let script = """
        set targetProfile to "\(profile.escapedForAppleScript())"
        with timeout of 3 seconds
          tell application "Terminal"
            if (count of windows) > 0 then
              try
                set current settings of selected tab of front window to settings set targetProfile
              end try
            end if
            set default settings to settings set targetProfile
            set startup settings to settings set targetProfile
          end tell
        end timeout
        """
        return execute(script: script)
    }

    private func applyToAllSessions(profile: String) -> Bool {
        let script = """
        set targetProfile to "\(profile.escapedForAppleScript())"
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
        return execute(script: script)
    }

    private func execute(script: String) -> Bool {
        guard let appleScript = NSAppleScript(source: script) else {
            logger.error("failed to compile NSAppleScript")
            return false
        }
        var errorDict: NSDictionary?
        appleScript.executeAndReturnError(&errorDict)
        if let error = errorDict {
            let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "unknown NSAppleScript error"
            let errorCode = error[NSAppleScript.errorNumber] as? Int ?? -1
            logger.error("AppleScript failed with status=\(errorCode, privacy: .public): \(errorMsg, privacy: .public)")
            return false
        }
        return true
    }
}

final class AppearanceSyncAgent: NSObject, NSApplicationDelegate {
    private let applyRunner: ApplyRunner
    private let logger: Logger
    private var lastIsDark: Bool?
    private var appearanceObservation: NSKeyValueObservation?

    init(config: Config) {
        self.logger = Logger(subsystem: "com.user.lumoshell", category: "agent")
        self.applyRunner = ApplyRunner(quiet: config.quiet, verbose: false, isManualApply: false, logger: self.logger)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("appearance sync agent started")
        trackAndApply(trigger: "startup", force: true)

        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            self?.trackAndApply(trigger: "effectiveAppearance", force: false)
        }
    }

    func start() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.delegate = self
        
        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigtermSource.setEventHandler {
            self.logger.info("received SIGTERM, exiting cleanly")
            exit(0)
        }
        sigtermSource.resume()
        // Ignore SIGTERM so the dispatch source can handle it
        signal(SIGTERM, SIG_IGN)

        app.run()
    }

    private func trackAndApply(trigger: String, force: Bool) {
        let isDark = isDarkAppearance()
        if !force, isDark == lastIsDark {
            return
        }
        lastIsDark = isDark
        applyRunner.run(trigger: trigger, isDark: isDark)
    }
}

func parseArgs(arguments: [String]) -> Config {
    var config = Config()
    var index = 0

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--apply":
            config.applyOnly = true
            index += 1
        case "--apply-new-session":
            config.applyNewSession = true
            index += 1
        case "--dry-run":
            config.dryRun = true
            index += 1
        case "--verbose":
            config.verbose = true
            index += 1
        case "--quiet":
            config.quiet = true
            index += 1
        case "--list-profiles":
            config.listProfiles = true
            index += 1
        case "-h", "--help":
            print("""
            Usage: lumoshell-appearance-sync-agent [options]

              --apply              Manually apply current mode and exit
              --apply-new-session  Manually apply current mode to active tab only and exit
              --list-profiles      Print all Terminal profiles and exit
              --dry-run            Print what would be applied without modifying Terminal
              --verbose            Print verbose apply output
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

if config.listProfiles {
    let path = ("~/Library/Preferences/com.apple.Terminal.plist" as NSString).expandingTildeInPath
    var profiles: [String] = []
    if let dict = NSDictionary(contentsOfFile: path),
       let settings = dict["Window Settings"] as? [String: Any] {
        profiles = Array(settings.keys)
    }
    if profiles.isEmpty {
        profiles = ["Basic", "Pro", "Ocean", "Homebrew"]
    }
    for profile in profiles.sorted() {
        print(profile)
    }
    exit(0)
}

if config.applyOnly || config.applyNewSession || config.dryRun {
    let logger = Logger(subsystem: "com.user.lumoshell", category: "agent")
    let runner = ApplyRunner(quiet: config.quiet, verbose: config.verbose, isManualApply: true, logger: logger)
    runner.run(trigger: "manual-cli", isDark: isDarkAppearance(), newSession: config.applyNewSession, dryRun: config.dryRun)
    exit(0)
}

let agent = AppearanceSyncAgent(config: config)
agent.start()
