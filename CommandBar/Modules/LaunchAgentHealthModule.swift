import SwiftUI
import Foundation

// ============================================================
// 🩺 LAUNCH AGENT HEALTH MODULE — full background-process monitor
// One pane, every background thing the Mac is running for you:
//   - 🧠  Brain health         (brain-health-status.json summary)
//   - ⚙️   My LaunchAgents      (~/Library/LaunchAgents — controllable)
//   - 🖥️  System Services      (/Library/LaunchAgents + /Library/LaunchDaemons)
//   - 🔄  PM2 Apps             (pm2 jlist, if installed)
//   - ⏰  Scheduled (cron)     (crontab -l + /etc/cron.d*)
//   - 🍎  Apple System         (/System/Library/… — search-only, never by default)
//
// Design notes:
//   - macOS 26 dropped `launchctl list -j`; we parse the classic
//     `PID  Status  Label` table instead.
//   - `launchctl list` only covers the user (gui/<uid>) domain, so
//     /Library/LaunchDaemons & Apple system services get plist metadata
//     but no live PID/exit (that needs root).
//   - Apple system services are 800+ and unmanageable — rendered only
//     when the search bar matches, capped to keep the pane fast.
// ============================================================

// MARK: - Health state

/// Tri-state health dot. 🚦
enum AgentState: Sendable, Equatable {
    case green, amber, red, unknown

    var color: Color {
        switch self {
        case .green:   return .green
        case .amber:   return .orange
        case .red:     return .red
        case .unknown: return .secondary
        }
    }

    var dotSymbol: String {
        switch self {
        case .green:   return "circle.fill"
        case .amber:   return "circle.fill"
        case .red:     return "exclamationmark.circle.fill"
        case .unknown: return "circle.dashed"
        }
    }

    var label: String {
        switch self {
        case .green:   return "Healthy"
        case .amber:   return "Stale"
        case .red:     return "Failing"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Launch service models

/// Where a service lives — drives grouping + controllability. 🗂️
enum ServiceKind: String, Sendable, CaseIterable, Identifiable {
    case userAgent       // ~/Library/LaunchAgents
    case systemAgent     // /Library/LaunchAgents
    case systemDaemon    // /Library/LaunchDaemons
    case appleSystem     // /System/Library/{LaunchAgents,LaunchDaemons}

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .userAgent:    return "My LaunchAgents"
        case .systemAgent:  return "System Agents"
        case .systemDaemon: return "System Daemons"
        case .appleSystem:  return "Apple System"
        }
    }

    var systemImage: String {
        switch self {
        case .userAgent:    return "person.crop.circle.badge.checkmark"
        case .systemAgent:  return "gearshape"
        case .systemDaemon: return "server.rack"
        case .appleSystem:  return "laptopcomputer"
        }
    }

    /// Can a non-root menu-bar app control this service?
    var userControllable: Bool {
        switch self {
        case .userAgent, .systemAgent: return true   // both live in gui/<uid>
        case .systemDaemon, .appleSystem: return false
        }
    }
}

/// Snapshot of a single launchd service. Pure value — Sendable. 📦
struct SystemService: Identifiable, Sendable, Equatable {
    let id: String              // full label
    let shortLabel: String
    let kind: ServiceKind
    let pid: Int?               // nil = not running / not in user domain
    let lastExitStatus: Int?    // LastExitStatus (nil = unknown for system daemons)
    let schedule: String
    let programSummary: String
    let logURL: URL?
    let lastActivity: Date?     // log mtime

    var isRunning: Bool { pid != nil }
    var controllable: Bool { kind.userControllable }

    /// green = running or recently active & clean
    /// red   = LastExitStatus≠0
    /// amber = idle + stale log (>90 min)
    /// unknown = no signal (typical for system daemons)
    var state: AgentState {
        if let status = lastExitStatus, status != 0 { return .red }
        if isRunning { return .green }
        if lastExitStatus == nil { return .unknown }   // system daemon w/o status
        if let last = lastActivity {
            return Date().timeIntervalSince(last) > 5400 ? .amber : .green
        }
        return .unknown
    }
}

/// PM2 process snapshot. 🔄
struct PM2App: Identifiable, Sendable, Equatable {
    let id: String          // name
    let pid: Int?
    let status: String      // "online" | "stopped" | "errored" | …
    let restarts: Int
    let uptime: Date?
    let cpu: Double?
    let memoryMB: Double?

    var isOnline: Bool { status == "online" }
    var state: AgentState {
        if isOnline { return .green }
        if status == "errored" { return .red }
        return .amber
    }
}

/// Cron job snapshot. ⏰
struct CronJob: Identifiable, Sendable, Equatable {
    let id: String          // "schedule | command | source"
    let schedule: String    // raw 5-field cron expr or descriptor
    let command: String
    let source: String      // "user" | "/etc/cron.d/foo"
    let enabled: Bool
}

/// Brain row snapshot. 🧠
struct BrainHealthSnapshot: Sendable, Equatable {
    let healthy: Bool
    let freshDays: Int
    let timestamp: Date?
    let sourceCount: Int
    let freshSourceCount: Int

    var symbol: String { healthy ? "brain.head.profile.fill" : "exclamationmark.octagon.fill" }
    var color: Color { healthy ? .green : .red }
}

/// Full Disk Access snapshot — best-effort (TCC.db may be unreadable). 🔐
struct FullDiskAccessSnapshot: Sendable, Equatable {
    let entries: [String: Bool]
    let available: Bool
}

// MARK: - SystemMonitorService (Sendable — all shell I/O off MainActor)

/// Stateless gatherer for everything background. Sendable → safe in Task.detached. 🛠️
struct SystemMonitorService: Sendable {

    let uid: Int = Int(getuid())

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    // MARK: Shell helpers

    /// Run a binary, return trimmed stdout. "" on failure.
    @discardableResult
    func run(_ cmd: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cmd)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return "" }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Run a shell snippet via login zsh (so PATH has homebrew/nvm). For PM2 etc.
    @discardableResult
    func runShell(_ command: String) -> String {
        run("/bin/zsh", ["-lc", command])
    }

    @discardableResult
    func runExit(_ cmd: String, _ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cmd)
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do { try process.run() } catch { return -1 }
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Fire-and-forget a shell command (for cron run-now / pm2 actions).
    func fireAndForget(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        // Don't wait — let it run in the background.
    }

    // MARK: launchctl

    /// `launchctl list` → [label: (pid, lastExit)]. Covers the gui/<uid> domain:
    /// ~/Library/LaunchAgents AND /Library/LaunchAgents appear here.
    func loadAgentStatusMap() -> [String: (pid: Int?, lastExit: Int?)] {
        let output = run("/bin/launchctl", ["list"])
        var map: [String: (pid: Int?, lastExit: Int?)] = [:]
        for line in output.split(separator: "\n").dropFirst() {
            let cols = line.split(omittingEmptySubsequences: true,
                                  whereSeparator: { $0.isWhitespace }).map(String.init)
            guard cols.count >= 3 else { continue }
            let pid = cols[0] == "-" ? nil : Int(cols[0])
            let last = Int(cols[1])
            let label = cols[2...].joined(separator: " ")
            map[label] = (pid, last)
        }
        return map
    }

    @discardableResult
    func kickstart(label: String) -> Int32 {
        runExit("/bin/launchctl", ["kickstart", "-k", "gui/\(uid)/\(label)"])
    }

    @discardableResult
    func stop(label: String) -> Int32 {
        // Kill the running instance but keep the job loaded (so it can fire next schedule).
        runExit("/bin/launchctl", ["kill", "SIGTERM", "gui/\(uid)/\(label)"])
    }

    // MARK: Plist parsing

    private func parsePlist(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        var format = PropertyListSerialization.PropertyListFormat.xml
        return (try? PropertyListSerialization.propertyList(
            from: data, options: [], format: &format) as? [String: Any])
    }

    private func scheduleString(_ plist: [String: Any]) -> String {
        if let cal = plist["StartCalendarInterval"] as? [String: Any] {
            return formatCalendarInterval(cal)
        }
        if let arr = plist["StartCalendarInterval"] as? [[String: Any]], let first = arr.first {
            return formatCalendarInterval(first)
        }
        if let interval = plist["StartInterval"] as? Int {
            if interval >= 3600, interval % 3600 == 0 {
                let hours = interval / 3600
                return hours == 1 ? "Hourly" : "Every \(hours)h"
            }
            if interval >= 60, interval % 60 == 0 {
                return "Every \(interval / 60) min"
            }
            return "Every \(interval)s"
        }
        if plist["KeepAlive"] != nil { return "Keep alive" }
        if plist["RunAtLoad"] as? Bool == true { return "Run at load" }
        return "Manual"
    }

    private func formatCalendarInterval(_ dict: [String: Any]) -> String {
        let hour = dict["Hour"] as? Int ?? 0
        let minute = dict["Minute"] as? Int ?? 0
        return String(format: "%02d:%02d daily", hour, minute)
    }

    private func logURL(from plist: [String: Any]) -> URL? {
        for key in ["StandardErrorPath", "StandardOutPath"] {
            if let path = plist[key] as? String, !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func mtime(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    func shortLabel(_ label: String) -> String {
        if let dot = label.lastIndex(of: ".") {
            return String(label[label.index(after: dot)...])
        }
        return label
    }

    // MARK: Gather launch services

    private struct PlistSource {
        let dir: URL
        let kind: ServiceKind
    }

    private var plistSources: [PlistSource] {
        [
            .init(dir: home.appendingPathComponent("Library/LaunchAgents", isDirectory: true), kind: .userAgent),
            .init(dir: URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true), kind: .systemAgent),
            .init(dir: URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true), kind: .systemDaemon),
            .init(dir: URL(fileURLWithPath: "/System/Library/LaunchAgents", isDirectory: true), kind: .appleSystem),
            .init(dir: URL(fileURLWithPath: "/System/Library/LaunchDaemons", isDirectory: true), kind: .appleSystem)
        ]
    }

    /// Gather services for the given kinds. Pass `.appleSystem` only with a
    /// non-empty `filter` — it's 800+ plists. 🍎
    func gatherServices(kinds: Set<ServiceKind>, filter: String = "") -> [SystemService] {
        let statusMap = loadAgentStatusMap()
        var seen = Set<String>()
        var services: [SystemService] = []
        let needle = filter.lowercased()

        for source in plistSources where kinds.contains(source.kind) {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: source.dir, includingPropertiesForKeys: nil).filter({ $0.pathExtension == "plist" })
            else { continue }

            for url in urls {
                guard let plist = parsePlist(url),
                      let label = plist["Label"] as? String else { continue }
                if seen.contains(label) { continue }
                seen.insert(label)

                // Apple system: include only when a search filter matches.
                if source.kind == .appleSystem {
                    let matchTarget = label.lowercased() + " " + shortLabel(label).lowercased()
                    guard !needle.isEmpty, matchTarget.contains(needle) else { continue }
                }

                let status = statusMap[label]
                let programArgs = (plist["ProgramArguments"] as? [String]) ?? []
                let programSummary = programArgs.last.map { ($0 as NSString).lastPathComponent } ?? "—"
                let log = logURL(from: plist)

                services.append(SystemService(
                    id: label,
                    shortLabel: shortLabel(label),
                    kind: source.kind,
                    pid: status?.pid,
                    lastExitStatus: status?.lastExit,
                    schedule: scheduleString(plist),
                    programSummary: programSummary,
                    logURL: log,
                    lastActivity: log.flatMap { mtime(of: $0) }
                ))
            }
        }

        return services.sorted { a, b in
            let aDaemon = a.kind == .systemDaemon || a.kind == .appleSystem
            let bDaemon = b.kind == .systemDaemon || b.kind == .appleSystem
            if aDaemon != bDaemon { return !aDaemon && bDaemon }   // agents first
            return a.shortLabel.localizedCaseInsensitiveCompare(b.shortLabel) == .orderedAscending
        }
    }

    // MARK: PM2

    /// Returns nil when pm2 isn't installed; empty list when installed but idle.
    func gatherPM2() -> [PM2App]? {
        let resolved = runShell("command -v pm2")
        guard !resolved.isEmpty else { return nil }
        let json = runShell("pm2 jlist")
        guard let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }

        return raw.map { p in
            let env = (p["pm2_env"] as? [String: Any]) ?? [:]
            let monit = (p["monit"] as? [String: Any]) ?? [:]
            let uptime: Date? = {
                if let ms = env["pm_uptime"] as? Double { return Date(timeIntervalSince1970: ms / 1000) }
                return nil
            }()
            return PM2App(
                id: (p["name"] as? String) ?? (p["pm_id"].map { "\($0)" } ?? "?"),
                pid: (p["pid"] as? Int),
                status: (env["status"] as? String) ?? "unknown",
                restarts: (env["restart_time"] as? Int) ?? 0,
                uptime: uptime,
                cpu: (monit["cpu"] as? Double),
                memoryMB: (monit["memory"] as? Double).map { $0 / 1_048_576 }
            )
        }
    }

    /// PM2 log file for an app (error log — where failures land).
    func pm2LogURL(for name: String) -> URL? {
        let path = home.appendingPathComponent(".pm2/logs/\(name)-error.log")
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    // MARK: Cron

    func gatherCron() -> [CronJob] {
        var jobs: [CronJob] = []

        // User crontab
        let userCron = run("/usr/bin/crontab", ["-l"])
        if !userCron.isEmpty, !userCron.lowercased().contains("no crontab") {
            jobs.append(contentsOf: parseCronLines(userCron, source: "user"))
        }

        // /etc/cron.d and the periodic cron directories
        let cronDirs = ["/etc/cron.d", "/etc/cron.hourly", "/etc/cron.daily",
                        "/etc/cron.weekly", "/etc/cron.monthly"]
        for dir in cronDirs {
            let dirURL = URL(fileURLWithPath: dir, isDirectory: true)
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: dirURL, includingPropertiesForKeys: nil) else { continue }
            for url in urls where !url.lastPathComponent.hasPrefix(".") {
                let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let parsed = parseCronLines(content, source: "\(dir)/\(url.lastPathComponent)")
                if parsed.isEmpty {
                    // Files in cron.hourly/daily/etc are scripts, not cron lines.
                    jobs.append(CronJob(
                        id: "\(dir)/\(url.lastPathComponent)",
                        schedule: cronScheduleHint(for: dir),
                        command: url.lastPathComponent,
                        source: "\(dir)/\(url.lastPathComponent)",
                        enabled: true
                    ))
                } else {
                    jobs.append(contentsOf: parsed)
                }
            }
        }

        return jobs
    }

    private func parseCronLines(_ text: String, source: String) -> [CronJob] {
        var jobs: [CronJob] = []
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            // A cron entry has at least 6 whitespace-delimited tokens.
            let tokens = line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            guard tokens.count >= 6 else { continue }
            let schedule = tokens[..<5].joined(separator: " ")
            let command = tokens[5...].joined(separator: " ")
            let id = "\(schedule) | \(command) | \(source)"
            jobs.append(CronJob(id: id, schedule: schedule, command: command, source: source, enabled: true))
        }
        return jobs
    }

    private func cronScheduleHint(for dir: String) -> String {
        switch dir {
        case "/etc/cron.hourly":  return "Hourly"
        case "/etc/cron.daily":   return "Daily"
        case "/etc/cron.weekly":  return "Weekly"
        case "/etc/cron.monthly": return "Monthly"
        default: return "Custom"
        }
    }

    // MARK: Brain health

    private var brainStatusURL: URL {
        home.appendingPathComponent("Library/Application Support/ai-config/brain-health-status.json")
    }

    func loadBrainHealth() -> BrainHealthSnapshot? {
        guard let data = try? Data(contentsOf: brainStatusURL) else { return nil }
        struct DTO: Decodable {
            let ts: String?
            let healthy: Bool?
            let fresh_days: Int?
            let sources: [String: Source]?
            struct Source: Decodable { let fresh: Bool? }
        }
        guard let dto = try? JSONDecoder().decode(DTO.self, from: data) else { return nil }
        let sources = dto.sources ?? [:]
        let fresh = sources.values.filter { $0.fresh == true }.count

        let ts: Date? = {
            guard let raw = dto.ts else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.date(from: raw)
        }()

        return BrainHealthSnapshot(
            healthy: dto.healthy ?? false,
            freshDays: dto.fresh_days ?? 0,
            timestamp: ts,
            sourceCount: sources.count,
            freshSourceCount: fresh
        )
    }

    // MARK: Full Disk Access (best-effort)

    func loadFullDiskAccess() -> FullDiskAccessSnapshot {
        let db = home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        let query = "SELECT client, auth_value FROM access WHERE service='kTCCServiceSystemPolicyAllFiles';"
        let out = run("/usr/bin/sqlite3", [db.path, query])
        guard !out.isEmpty, !out.lowercased().contains("error") else {
            return FullDiskAccessSnapshot(entries: [:], available: false)
        }
        var entries: [String: Bool] = [:]
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2, let value = Int(parts[1]) else { continue }
            let name = (parts[0] as NSString).lastPathComponent
            entries[name] = value > 0
        }
        return FullDiskAccessSnapshot(entries: entries, available: true)
    }
}

// MARK: - Sort

enum ServiceSortMode: String, CaseIterable, Identifiable {
    case name, status, lastRun
    var id: String { rawValue }
    var label: String {
        switch self {
        case .name:    return "Name"
        case .status:  return "Status"
        case .lastRun: return "Last run"
        }
    }
}

private func sortServices(_ services: [SystemService], by mode: ServiceSortMode) -> [SystemService] {
    switch mode {
    case .name:
        return services.sorted { $0.shortLabel.localizedCaseInsensitiveCompare($1.shortLabel) == .orderedAscending }
    case .status:
        // red → amber → unknown → green, then by name.
        let rank: (AgentState) -> Int = { s in
            switch s { case .red: 0; case .amber: 1; case .unknown: 2; case .green: 3 }
        }
        return services.sorted {
            let r = rank($0.state) - rank($1.state)
            return r == 0 ? $0.shortLabel < $1.shortLabel : r < 0
        }
    case .lastRun:
        return services.sorted {
            let l0 = $0.lastActivity ?? .distantPast
            let l1 = $1.lastActivity ?? .distantPast
            return l0 > l1
        }
    }
}

// MARK: - Module

@MainActor
final class LaunchAgentHealthModule: ObservableObject, CommandBarModule {
    let id = "launchagent-health"
    let sfSymbol = "stethoscope"
    let accentColor = Color.purple
    var stripLabel: String { "Agents" }

    // Grouped launch services (non-Apple).
    @Published private(set) var userAgents: [SystemService] = []
    @Published private(set) var systemAgents: [SystemService] = []
    @Published private(set) var systemDaemons: [SystemService] = []

    // Search-only Apple results.
    @Published private(set) var appleResults: [SystemService] = []

    @Published private(set) var pm2Apps: [PM2App]? = nil   // nil = not installed
    @Published private(set) var cronJobs: [CronJob] = []
    @Published private(set) var brain: BrainHealthSnapshot?
    @Published private(set) var fda: FullDiskAccessSnapshot = .init(entries: [:], available: false)

    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var isRunningAction = false
    @Published private(set) var statusMessage: String?

    // UI state
    @Published var searchText: String = ""
    @Published var sortMode: ServiceSortMode = .name

    private var autoTimer: Timer?

    init() {
        Task { await refresh() }
        autoTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
    }

    deinit { autoTimer?.invalidate() }

    // MARK: Refresh

    func refresh() async {
        let snapshot = await Task.detached(priority: .utility) {
            let service = SystemMonitorService()
            let kinds: Set<ServiceKind> = [.userAgent, .systemAgent, .systemDaemon]
            let services = service.gatherServices(kinds: kinds)
            return (
                userAgents: services.filter { $0.kind == .userAgent },
                systemAgents: services.filter { $0.kind == .systemAgent },
                systemDaemons: services.filter { $0.kind == .systemDaemon },
                pm2: service.gatherPM2(),
                cron: service.gatherCron(),
                brain: service.loadBrainHealth(),
                fda: service.loadFullDiskAccess()
            )
        }.value

        self.userAgents = sortServices(snapshot.userAgents, by: sortMode)
        self.systemAgents = sortServices(snapshot.systemAgents, by: sortMode)
        self.systemDaemons = sortServices(snapshot.systemDaemons, by: sortMode)
        self.pm2Apps = snapshot.pm2
        self.cronJobs = snapshot.cron
        self.brain = snapshot.brain
        self.fda = snapshot.fda
        self.lastRefreshed = Date()

        // If the user is searching Apple services, refresh those results too.
        if !searchText.isEmpty { await searchApple() }
    }

    /// Search Apple's /System services on demand (800+ plists — never by default).
    func searchApple() async {
        let needle = searchText
        guard !needle.isEmpty else { appleResults = []; return }
        let results = await Task.detached(priority: .utility) {
            SystemMonitorService().gatherServices(kinds: [.appleSystem], filter: needle)
        }.value
        appleResults = Array(results.prefix(50))   // cap rendering
    }

    // MARK: Filtering (search applies across visible groups)

    private func matchesSearch(_ s: SystemService) -> Bool {
        guard !searchText.isEmpty else { return true }
        let needle = searchText.lowercased()
        return s.id.lowercased().contains(needle) || s.shortLabel.lowercased().contains(needle)
    }

    var filteredUserAgents: [SystemService] { sortServices(userAgents.filter { matchesSearch($0) }, by: sortMode) }
    var filteredSystemAgents: [SystemService] { sortServices(systemAgents.filter { matchesSearch($0) }, by: sortMode) }
    var filteredSystemDaemons: [SystemService] { sortServices(systemDaemons.filter { matchesSearch($0) }, by: sortMode) }

    // MARK: Actions — launchd (user-controllable)

    /// Run / restart a controllable user-domain service. ⚡
    func runNow(service: SystemService) async {
        guard service.controllable else { return }
        await performKickstart(label: service.id) {
            "✓ Triggered \(SystemMonitorService().shortLabel(service.id))"
        }
    }

    /// Stop a running user-domain service (keeps it loaded). ⏹️
    func stop(service: SystemService) async {
        guard service.controllable else { return }
        let exit = await runOffActor { SystemMonitorService().stop(label: service.id) }
        statusMessage = exit == 0
            ? "✓ Stopped \(SystemMonitorService().shortLabel(service.id))"
            : "✗ stop failed (\(exit))"
        try? await Task.sleep(for: .seconds(2))
        await refresh()
    }

    func runBrainSyncNow() async {
        await performKickstart(label: "com.gurinder.brain-sync") { "✓ Triggered brain-sync" }
    }

    // MARK: Actions — PM2

    func pm2Restart(_ app: PM2App) async {
        await runShellAction("pm2 restart \(shellQuote(app.id))") { "✓ PM2 restart \(app.id)" }
    }
    func pm2Stop(_ app: PM2App) async {
        await runShellAction("pm2 stop \(shellQuote(app.id))") { "✓ PM2 stop \(app.id)" }
    }
    func pm2Logs(_ app: PM2App) {
        if let url = SystemMonitorService().pm2LogURL(for: app.id) {
            NSWorkspace.shared.open(url)
        } else {
            statusMessage = "No PM2 log found for \(app.id)"
        }
    }

    // MARK: Actions — cron

    /// Run the command now, in the background. 🏃
    func runCronNow(_ job: CronJob) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", job.command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        let preview = job.command.prefix(40)
        statusMessage = "✓ Cron fired: \(preview)\(job.command.count > 40 ? "…" : "")"
    }

    // MARK: Open log

    func openLog(for service: SystemService) {
        guard let url = service.logURL else { return }
        NSWorkspace.shared.open(url)
    }
    func openBrainLog() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/brain-sync.log")
        NSWorkspace.shared.open(url)
    }

    var fdaSummary: String? {
        guard fda.available else { return "FDA status unavailable (needs Full Disk Access)" }
        let targets = ["python3.12", "claude"]
        let parts = targets.map { name -> String in
            switch fda.entries[name] {
            case true:  return "\(name) ✓"
            case false: return "\(name) ✗"
            case nil:   return "\(name) ?"
            }
        }
        return "FDA: " + parts.joined(separator: " · ")
    }

    // MARK: Action plumbing

    private func performKickstart(label: String, message: @escaping @Sendable () -> String) async {
        guard !isRunningAction else { return }
        isRunningAction = true
        defer { isRunningAction = false }
        let exit = await runOffActor { SystemMonitorService().kickstart(label: label) }
        statusMessage = exit == 0 ? message() : "✗ kickstart failed (\(exit))"
        try? await Task.sleep(for: .seconds(2))
        await refresh()
    }

    private func runShellAction(_ command: String, message: @escaping @Sendable () -> String) async {
        guard !isRunningAction else { return }
        isRunningAction = true
        defer { isRunningAction = false }
        await runOffActor { SystemMonitorService().fireAndForget(command) }
        statusMessage = message()
        try? await Task.sleep(for: .seconds(2))
        await refresh()
    }

    private func runOffActor<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await Task.detached(priority: .userInitiated) { work() }.value
    }
}

private func shellQuote(_ s: String) -> String {
    "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

// MARK: - Expanded view

struct LaunchAgentHealthExpandedView: View {
    @ObservedObject var module: LaunchAgentHealthModule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            searchBar
            Divider()
            brainRow
            Divider()
            servicesGroup
            pm2Group
            cronGroup
            appleGroup
            footer
        }
        .padding(12)
    }

    // MARK: Header + search

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: module.sfSymbol)
                .foregroundColor(module.accentColor)
                .font(.system(size: 14, weight: .semibold))
            Text("System Monitor")
                .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
            Spacer()
            if let last = module.lastRefreshed {
                Text("updated \(last.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Button {
                Task { await module.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise").foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            TextField("Filter services…", text: $module.searchText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .onChange(of: module.searchText) { _, newValue in
                    if !newValue.isEmpty {
                        Task { await module.searchApple() }
                    }
                }
            Picker("", selection: $module.sortMode) {
                ForEach(ServiceSortMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .labelsHidden()
            .help("Sort")
        }
    }

    // MARK: Brain row

    @ViewBuilder
    private var brainRow: some View {
        if let brain = module.brain {
            HStack(spacing: 10) {
                Image(systemName: brain.symbol)
                    .foregroundColor(brain.color)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Brain health")
                        .font(.system(size: 12, weight: .semibold))
                    Text(brain.healthy
                        ? "Healthy · \(brain.freshSourceCount)/\(brain.sourceCount) sources fresh · \(brain.freshDays)d"
                        : "Unhealthy · \(brain.freshSourceCount)/\(brain.sourceCount) fresh")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    Task { await module.runBrainSyncNow() }
                } label: {
                    Label("Sync now", systemImage: "play.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(module.isRunningAction)
                Button {
                    module.openBrainLog()
                } label: {
                    Image(systemName: "doc.text.magnifyingglass").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open brain-sync log")
            }
            .padding(8)
            .background(brain.color.opacity(0.06))
            .cornerRadius(6)
        } else {
            Text("brain-health-status.json not found")
                .font(.system(size: 11)).foregroundColor(.secondary)
        }
    }

    // MARK: Services group

    @ViewBuilder
    private var servicesGroup: some View {
        ForEach(ServiceKind.allCases.filter { $0 != .appleSystem }) { kind in
            let rows = rowsFor(kind: kind)
            if !rows.isEmpty {
                SectionHeader(title: kind.displayName, systemImage: kind.systemImage, count: rows.count)
                VStack(spacing: 2) {
                    ForEach(rows) { service in
                        ServiceRow(
                            service: service,
                            isRunningAction: module.isRunningAction,
                            onRun: { Task { await module.runNow(service: service) } },
                            onStop: { Task { await module.stop(service: service) } },
                            onOpen: { module.openLog(for: service) }
                        )
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func rowsFor(kind: ServiceKind) -> [SystemService] {
        switch kind {
        case .userAgent:    return module.filteredUserAgents
        case .systemAgent:  return module.filteredSystemAgents
        case .systemDaemon: return module.filteredSystemDaemons
        case .appleSystem:  return module.appleResults
        }
    }

    // MARK: PM2

    @ViewBuilder
    private var pm2Group: some View {
        if let apps = module.pm2Apps {
            SectionHeader(title: "PM2 Apps", systemImage: "arrow.triangle.2.circlepath", count: apps.count)
            if apps.isEmpty {
                Text("No PM2 processes")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .padding(.leading, 4).padding(.bottom, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(apps) { app in
                        PM2Row(
                            app: app,
                            onRestart: { Task { await module.pm2Restart(app) } },
                            onStop: { Task { await module.pm2Stop(app) } },
                            onLogs: { module.pm2Logs(app) }
                        )
                    }
                }
                .padding(.bottom, 4)
            }
        } else if module.lastRefreshed != nil {
            Text("PM2 not installed")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .padding(.leading, 4).padding(.bottom, 4)
        }
    }

    // MARK: Cron

    @ViewBuilder
    private var cronGroup: some View {
        if !module.cronJobs.isEmpty {
            SectionHeader(title: "Scheduled (cron)", systemImage: "clock", count: module.cronJobs.count)
            VStack(spacing: 2) {
                ForEach(module.cronJobs) { job in
                    CronRow(job: job, onRun: { module.runCronNow(job) })
                }
            }
            .padding(.bottom, 4)
        } else if module.lastRefreshed != nil {
            Text("No cron jobs")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .padding(.leading, 4).padding(.bottom, 4)
        }
    }

    // MARK: Apple (search-only)

    @ViewBuilder
    private var appleGroup: some View {
        if !module.searchText.isEmpty && !module.appleResults.isEmpty {
            SectionHeader(title: "Apple System (matching)", systemImage: "laptopcomputer", count: module.appleResults.count)
            VStack(spacing: 2) {
                ForEach(module.appleResults) { service in
                    ServiceRow(
                        service: service,
                        isRunningAction: module.isRunningAction,
                        onRun: { },
                        onStop: { },
                        onOpen: { module.openLog(for: service) }
                    )
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if let fda = module.fdaSummary {
            Text(fda)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        if let status = module.statusMessage {
            Text(status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    let systemImage: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 4)
    }
}

// MARK: - Service row

struct ServiceRow: View {
    let service: SystemService
    let isRunningAction: Bool
    let onRun: () -> Void
    let onStop: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: service.state.dotSymbol)
                .foregroundColor(service.state.color)
                .font(.system(size: 11))
                .frame(width: 14)
                .help(service.state.label)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(service.shortLabel)
                        .font(.system(size: 12, weight: .medium))
                    if let pid = service.pid {
                        Text("pid \(pid)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if let status = service.lastExitStatus, status != 0 {
                        Text("exit \(status)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.red)
                    }
                    if !service.controllable {
                        Text("root")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .help("Needs root to control")
                    }
                }
                HStack(spacing: 6) {
                    Text(service.schedule)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if let last = service.lastActivity {
                        Text("· ran \(last.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if service.controllable {
                Button(action: onRun) {
                    Image(systemName: "play.fill").font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(isRunningAction)
                .help("Run now (launchctl kickstart)")

                Button(action: onStop) {
                    Image(systemName: "stop.fill").font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(isRunningAction || !service.isRunning)
                .help("Stop (launchctl kill)")
            }

            Button(action: onOpen) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open log")
            .disabled(service.logURL == nil)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
    }
}

// MARK: - PM2 row

struct PM2Row: View {
    let app: PM2App
    let onRestart: () -> Void
    let onStop: () -> Void
    let onLogs: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: app.state.dotSymbol)
                .foregroundColor(app.state.color)
                .font(.system(size: 11))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(app.id)
                        .font(.system(size: 12, weight: .medium))
                    Text(app.status)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(app.isOnline ? .green : .secondary)
                    if let cpu = app.cpu {
                        Text("cpu \(Int(cpu))%")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if let mem = app.memoryMB {
                        Text(String(format: "%.0fMB", mem))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text("restarts \(app.restarts)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if let up = app.uptime {
                        Text("· up \(up.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button(action: onRestart) {
                Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 10))
            }
            .buttonStyle(.bordered).controlSize(.mini)
            .help("pm2 restart")

            Button(action: onStop) {
                Image(systemName: "stop.fill").font(.system(size: 10))
            }
            .buttonStyle(.bordered).controlSize(.mini)
            .disabled(!app.isOnline)
            .help("pm2 stop")

            Button(action: onLogs) {
                Image(systemName: "doc.text").font(.system(size: 10)).foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open PM2 error log")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
    }
}

// MARK: - Cron row

struct CronRow: View {
    let job: CronJob
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 10))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(job.command)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(job.schedule)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("· \(job.source)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onRun) {
                Image(systemName: "play.fill").font(.system(size: 10))
            }
            .buttonStyle(.bordered).controlSize(.mini)
            .help("Run now")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
    }
}
