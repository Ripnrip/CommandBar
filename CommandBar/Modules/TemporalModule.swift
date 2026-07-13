import SwiftUI
import Foundation

// ============================================================
// 🎬 TEMPORAL MODULE — Gource playback + git-history activity feed
// One pane for the "time machine" view of the whole 149-repo fleet:
//   - ▶️  Play Gource        (animated git-history playback window)
//   - 🎞️  Render video       (detached ffmpeg render to ~/Desktop)
//   - 🔁  Re-index now       (rebuild the combined Gource log)
//   - 📜  Recent activity    (last N changes grouped by repo)
//   - 📌  Snapshot / Wiki    (read-only status from the AI-Config vault)
//
// Design notes:
//   - Gource is a one-shot CLI tool, NOT a daemon — nothing to poll for
//     health. We watch the combined-log file (mtime + event count) instead.
//   - /snapshot and /wiki are Claude Code slash commands and can't be run
//     from a compiled binary, so those rows are read-only status + a
//     "Copy /snapshot command" clipboard affordance (honest, not fake).
//   - The Gource script self-inserts its dir on sys.path and shells out to
//     the `gource` binary, so we invoke it through a login zsh to inherit
//     the Homebrew PATH.
//   - No OS-notification layer exists in this app yet (other modules use an
//     inline statusMessage), so notifications reuse the app's shell-out
//     habit via `osascript display notification` — bundle-independent and
//     safe for a SwiftPM executable.
// ============================================================

// MARK: - Models

/// A single parsed Gource custom-log event: `epoch|author|action|repo/path`. 📦
struct GourceEvent: Sendable, Equatable {
    let epoch: Int
    let author: String
    let action: String     // A / M / D
    let repo: String       // top-level path component
    let path: String       // full repo/relative path
}

/// Per-repo rollup of recent activity. 📜
struct RepoActivity: Identifiable, Sendable, Equatable {
    let id: String          // repo name
    let changeCount: Int
    let lastEpoch: Int

    var lastActivity: Date { Date(timeIntervalSince1970: TimeInterval(lastEpoch)) }
}

/// Immutable snapshot gathered off the main actor. 🧊
struct TemporalSnapshot: Sendable {
    let logExists: Bool
    let lastIndexed: Date?          // mtime of gource-combined.log
    let totalEvents: Int            // line count of the combined log
    let tailEvents: [GourceEvent]   // last window of parsed events
    let recent: [RepoActivity]      // grouped rollup (top repos)
    let lastSnapshotName: String?
    let lastSnapshotDate: Date?
    let wikiRepoCount: Int
    let wikiLastRefresh: Date?
}

// MARK: - Service (Sendable — all file/shell I/O off MainActor)

/// Stateless gatherer + action runner for the Temporal module. 🛠️
struct TemporalService: Sendable {

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    var scriptURL: URL {
        home.appendingPathComponent("Documents/Developer/ai-ide-setup/scripts/gource-multirepo.py")
    }
    var combinedLogURL: URL {
        home.appendingPathComponent("Library/Application Support/ai-config/gource-combined.log")
    }
    private var checkpointsURL: URL {
        home.appendingPathComponent("Documents/Obsidian/vault/AI-Config/checkpoints.md")
    }
    private var wikiDirURL: URL {
        home.appendingPathComponent("Documents/Obsidian/vault/AI-Config/wiki")
    }

    // MARK: Shell helpers

    /// Run a shell snippet through a login zsh so PATH has homebrew (gource, ffmpeg). ⚙️
    /// Waits for completion; returns true on exit status 0.
    @discardableResult
    func runToCompletion(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do { try process.run() } catch { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// Fire-and-forget a shell command (for Gource playback which opens its own window). 🏃
    func fireAndForget(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
    }

    /// Post a macOS user notification via osascript (no bundle required). 🔔
    func notify(title: String, message: String) {
        let safeTitle = appleScriptEscape(title)
        let safeMessage = appleScriptEscape(message)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "display notification \"\(safeMessage)\" with title \"\(safeTitle)\""]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
    }

    private func appleScriptEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: Actions

    var scriptExists: Bool { FileManager.default.fileExists(atPath: scriptURL.path) }

    func playGource() {
        fireAndForget("python3 \(shellQuote(scriptURL.path)) --play")
    }

    /// Rebuild the combined log (no playback). Blocks — call off the main actor. 🔁
    @discardableResult
    func reindex() -> Bool {
        runToCompletion("python3 \(shellQuote(scriptURL.path))")
    }

    /// Render an MP4 to the given path. Blocks (can take a while). 🎞️
    @discardableResult
    func renderVideo(to outputPath: String) -> Bool {
        runToCompletion("python3 \(shellQuote(scriptURL.path)) --output-video \(shellQuote(outputPath))")
    }

    // MARK: Gather

    func gather() -> TemporalSnapshot {
        let (exists, mtime, total, tail) = loadGource()
        let recent = rollup(tail)
        let (snapName, snapDate) = loadLatestSnapshot()
        let (wikiCount, wikiRefresh) = loadWikiStatus()
        return TemporalSnapshot(
            logExists: exists,
            lastIndexed: mtime,
            totalEvents: total,
            tailEvents: tail,
            recent: recent,
            lastSnapshotName: snapName,
            lastSnapshotDate: snapDate,
            wikiRepoCount: wikiCount,
            wikiLastRefresh: wikiRefresh
        )
    }

    /// Read the combined log: existence, mtime, total event count, and a tail window. 📖
    private func loadGource() -> (exists: Bool, mtime: Date?, total: Int, tail: [GourceEvent]) {
        guard let content = try? String(contentsOf: combinedLogURL, encoding: .utf8) else {
            return (false, nil, 0, [])
        }
        let mtime = try? combinedLogURL.resourceValues(
            forKeys: [.contentModificationDateKey]).contentModificationDate
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        let tail = lines.suffix(60).compactMap { parseEvent(String($0)) }
        return (true, mtime, lines.count, tail)
    }

    private func parseEvent(_ line: String) -> GourceEvent? {
        let parts = line.split(separator: "|", maxSplits: 3,
                               omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, let epoch = Int(parts[0]) else { return nil }
        let fullPath = parts[3]
        let repo = fullPath.split(separator: "/", maxSplits: 1).first.map(String.init) ?? fullPath
        return GourceEvent(epoch: epoch, author: parts[1], action: parts[2], repo: repo, path: fullPath)
    }

    /// Group a window of events by repo → count + most-recent epoch, top 10 by recency. 📊
    private func rollup(_ events: [GourceEvent]) -> [RepoActivity] {
        var counts: [String: Int] = [:]
        var latest: [String: Int] = [:]
        for e in events.suffix(50) {
            counts[e.repo, default: 0] += 1
            latest[e.repo] = max(latest[e.repo] ?? 0, e.epoch)
        }
        return counts.map { RepoActivity(id: $0.key, changeCount: $0.value, lastEpoch: latest[$0.key] ?? 0) }
            .sorted { $0.lastEpoch > $1.lastEpoch }
            .prefix(10)
            .map { $0 }
    }

    /// Most recent `## [YYYY-MM-DD HH:mm] name — repo` entry in checkpoints.md. 📌
    private func loadLatestSnapshot() -> (name: String?, date: Date?) {
        guard let content = try? String(contentsOf: checkpointsURL, encoding: .utf8) else { return (nil, nil) }
        for raw in content.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("## ["),
                  let close = line.firstIndex(of: "]") else { continue }
            let dateStr = String(line[line.index(line.startIndex, offsetBy: 4)..<close])
            var name = String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            // Trim the " — repo" suffix (em dash or hyphen).
            for sep in [" — ", " - "] {
                if let r = name.range(of: sep) { name = String(name[..<r.lowerBound]); break }
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return (name.isEmpty ? nil : name, formatter.date(from: dateStr))
        }
        return (nil, nil)
    }

    /// Count generated wiki pages (excluding _index.md) + newest refresh mtime. 📚
    private func loadWikiStatus() -> (count: Int, refresh: Date?) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: wikiDirURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return (0, nil)
        }
        let pages = urls.filter { $0.pathExtension == "md" && $0.lastPathComponent != "_index.md" }
        let newest = urls.compactMap {
            try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }.max()
        return (pages.count, pages.isEmpty ? nil : newest)
    }
}

private func shellQuote(_ s: String) -> String {
    "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

// MARK: - Module

@MainActor
final class TemporalModule: ObservableObject, CommandBarModule {
    let id = "temporal"
    let sfSymbol = "film.stack"
    let accentColor = Color.indigo
    var stripLabel: String { "Temporal" }

    @Published private(set) var logExists = false
    @Published private(set) var lastIndexed: Date?
    @Published private(set) var totalEvents = 0
    @Published private(set) var recent: [RepoActivity] = []

    @Published private(set) var lastSnapshotName: String?
    @Published private(set) var lastSnapshotDate: Date?
    @Published private(set) var wikiRepoCount = 0
    @Published private(set) var wikiLastRefresh: Date?

    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var isReindexing = false
    @Published private(set) var isRendering = false
    @Published private(set) var statusMessage: String?

    /// Baseline event count for new-activity detection across polls.
    private var previousEventCount: Int?
    /// Suppress the "new commits" notification on the refresh right after our own reindex.
    private var suppressNextNotification = false

    var scriptAvailable: Bool { TemporalService().scriptExists }

    /// Suggested snapshot name to paste into a Claude Code session. 📋
    var suggestedSnapshotCommand: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "/snapshot \(formatter.string(from: Date()))-wip"
    }

    // MARK: Refresh (driven by AppState.refreshAll on the app-wide cycle)

    func refresh() async {
        let snapshot = await Task.detached(priority: .utility) {
            TemporalService().gather()
        }.value

        // New-activity notification: fire only when the log grew since the last
        // poll AND we have a prior baseline that wasn't set by our own reindex.
        if let prev = previousEventCount, snapshot.totalEvents > prev, !suppressNextNotification {
            let delta = snapshot.totalEvents - prev
            let newRepos = orderedUniqueRepos(snapshot.tailEvents.suffix(delta))
            let reposLabel = newRepos.isEmpty ? "the fleet" : newRepos.prefix(3).joined(separator: ", ")
                + (newRepos.count > 3 ? " +\(newRepos.count - 3) more" : "")
            TemporalService().notify(
                title: "🎬 Temporal",
                message: "\(delta) new change\(delta == 1 ? "" : "s") across \(reposLabel)"
            )
        }
        suppressNextNotification = false
        previousEventCount = snapshot.totalEvents

        logExists = snapshot.logExists
        lastIndexed = snapshot.lastIndexed
        totalEvents = snapshot.totalEvents
        recent = snapshot.recent
        lastSnapshotName = snapshot.lastSnapshotName
        lastSnapshotDate = snapshot.lastSnapshotDate
        wikiRepoCount = snapshot.wikiRepoCount
        wikiLastRefresh = snapshot.wikiLastRefresh
        lastRefreshed = Date()
    }

    /// Distinct repos in event order (newest-window first-seen wins). 🔤
    private func orderedUniqueRepos<S: Sequence>(_ events: S) -> [String] where S.Element == GourceEvent {
        var seen = Set<String>()
        var ordered: [String] = []
        for e in events where !seen.contains(e.repo) {
            seen.insert(e.repo); ordered.append(e.repo)
        }
        return ordered
    }

    // MARK: Actions

    /// Launch the live Gource playback window (opens its own OpenGL window). ▶️
    func playGource() {
        guard scriptAvailable else { statusMessage = "gource-multirepo.py not found"; return }
        statusMessage = "▶️ Launching Gource…"
        Task.detached(priority: .userInitiated) { TemporalService().playGource() }
    }

    /// Rebuild the combined log, then refresh + report. 🔁
    func reindexNow() async {
        guard scriptAvailable else { statusMessage = "gource-multirepo.py not found"; return }
        guard !isReindexing else { return }
        isReindexing = true
        statusMessage = "🔁 Re-indexing 149 repos…"
        let ok = await Task.detached(priority: .userInitiated) { TemporalService().reindex() }.value
        isReindexing = false
        statusMessage = ok ? "✓ Re-indexed combined log" : "✗ Re-index failed"
        suppressNextNotification = true   // don't alert on our own rebuild
        await refresh()
    }

    /// Render an MP4 to the Desktop, detached; notify on completion. 🎞️
    func renderVideo() {
        guard scriptAvailable else { statusMessage = "gource-multirepo.py not found"; return }
        guard !isRendering else { return }
        isRendering = true
        let stamp = timestamp()
        let outputPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/infra-history-\(stamp).mp4").path
        statusMessage = "🎞️ Rendering video (this can take a while)…"
        Task {
            let ok = await Task.detached(priority: .utility) {
                TemporalService().renderVideo(to: outputPath)
            }.value
            self.isRendering = false
            self.statusMessage = ok ? "✓ Rendered infra-history-\(stamp).mp4" : "✗ Render failed"
            TemporalService().notify(
                title: "🎬 Temporal",
                message: ok ? "Video rendered to Desktop/infra-history-\(stamp).mp4" : "Video render failed"
            )
        }
    }

    /// Copy the suggested /snapshot command to the clipboard. 📋
    func copySnapshotCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(suggestedSnapshotCommand, forType: .string)
        statusMessage = "📋 Copied: \(suggestedSnapshotCommand)"
    }

    func openCombinedLog() {
        NSWorkspace.shared.open(TemporalService().combinedLogURL)
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}

// MARK: - Expanded view

struct TemporalExpandedView: View {
    @ObservedObject var module: TemporalModule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            actionsRow
            Divider()
            recentActivity
            Divider()
            snapshotWikiStatus
            footer
        }
        .padding(12)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: module.sfSymbol)
                .foregroundColor(module.accentColor)
                .font(.system(size: 14, weight: .semibold))
            Text("Temporal")
                .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
            Spacer()
            if let last = module.lastIndexed {
                Text("indexed \(last.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Button {
                module.playGource()
            } label: {
                Label("Play Gource", systemImage: "play.circle.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(module.accentColor)
            .disabled(!module.scriptAvailable)
            .help("Launch the animated Gource git-history playback")
        }
    }

    // MARK: Actions

    private var actionsRow: some View {
        HStack(spacing: 8) {
            Button {
                module.renderVideo()
            } label: {
                Label(module.isRendering ? "Rendering…" : "Render video",
                      systemImage: module.isRendering ? "hourglass" : "film")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(module.isRendering || !module.scriptAvailable)
            .help("Render an MP4 of the combined history to your Desktop")

            Button {
                Task { await module.reindexNow() }
            } label: {
                Label(module.isReindexing ? "Re-indexing…" : "Re-index now",
                      systemImage: module.isReindexing ? "hourglass" : "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(module.isReindexing || !module.scriptAvailable)
            .help("Rebuild the combined Gource log from all repos")

            Spacer()

            if module.totalEvents > 0 {
                Text("\(module.totalEvents) events")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Button {
                module.openCombinedLog()
            } label: {
                Image(systemName: "doc.text.magnifyingglass").foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!module.logExists)
            .help("Open the combined Gource log")
        }
    }

    // MARK: Recent activity

    @ViewBuilder
    private var recentActivity: some View {
        SectionHeader(title: "Recent activity", systemImage: "clock.arrow.circlepath", count: module.recent.count)
        if module.recent.isEmpty {
            Text(module.logExists ? "No recent changes parsed" : "Combined log not built yet — Re-index now")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .padding(.leading, 4).padding(.bottom, 4)
        } else {
            VStack(spacing: 2) {
                ForEach(module.recent) { activity in
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                            .frame(width: 14)
                        Text(activity.id)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("\(activity.changeCount) change\(activity.changeCount == 1 ? "" : "s")")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(activity.lastActivity.formatted(.relative(presentation: .named)))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: Snapshot + Wiki (read-only status)

    @ViewBuilder
    private var snapshotWikiStatus: some View {
        SectionHeader(title: "Snapshot & Wiki", systemImage: "bookmark.fill", count: 0)

        HStack(spacing: 10) {
            Image(systemName: "bookmark.circle.fill")
                .foregroundColor(module.accentColor)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("Last snapshot")
                    .font(.system(size: 12, weight: .semibold))
                if let name = module.lastSnapshotName {
                    Text("\(name)\(module.lastSnapshotDate.map { " · " + $0.formatted(.relative(presentation: .named)) } ?? "")")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                } else {
                    Text("none recorded")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button {
                module.copySnapshotCommand()
            } label: {
                Label("Copy /snapshot", systemImage: "doc.on.clipboard")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Copy a suggested /snapshot command to paste into a Claude Code session")
        }
        .padding(8)
        .background(module.accentColor.opacity(0.06))
        .cornerRadius(6)

        HStack(spacing: 10) {
            Image(systemName: "books.vertical.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 15))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("Wiki")
                    .font(.system(size: 12, weight: .semibold))
                if module.wikiRepoCount > 0 {
                    Text("\(module.wikiRepoCount) repo\(module.wikiRepoCount == 1 ? "" : "s") indexed\(module.wikiLastRefresh.map { " · last refresh " + $0.formatted(.relative(presentation: .named)) } ?? "")")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                } else {
                    Text("not yet generated")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if let status = module.statusMessage {
            Text(status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        if !module.scriptAvailable {
            Text("gource-multirepo.py not found at ~/Documents/Developer/ai-ide-setup/scripts/")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.orange)
        }
    }
}
