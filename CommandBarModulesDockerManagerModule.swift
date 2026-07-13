import SwiftUI
import Foundation

// MARK: - Docker Manager Module

@MainActor
class DockerManagerModule: ObservableObject {
    @Published var containers: [DockerContainer] = []
    @Published var images: [DockerImage] = []
    @Published var isLoading: Bool = false
    @Published var statusMessage: String?
    @Published var dockerAvailable: Bool = false
    
    var title: String { "Docker" }
    
    init() {
        Task {
            await checkDockerAvailability()
            if dockerAvailable {
                await refresh()
            }
        }
    }
    
    func checkDockerAvailability() async {
        let result = await runDockerCommand(["--version"])
        dockerAvailable = result.success
        if !dockerAvailable {
            statusMessage = "Docker not available. Is it installed and running?"
        }
    }
    
    func refresh() async {
        isLoading = true
        statusMessage = nil
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadContainers()
            }
            group.addTask {
                await self.loadImages()
            }
        }
        
        isLoading = false
    }
    
    private func loadContainers() async {
        // docker ps -a --format json
        let result = await runDockerCommand([
            "ps", "-a",
            "--format", "{{json .}}"
        ])
        
        guard result.success else {
            statusMessage = "Failed to load containers"
            return
        }
        
        var loadedContainers: [DockerContainer] = []
        
        for line in result.output.split(separator: "\n") {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let container = DockerContainer(
                    id: json["ID"] as? String ?? "",
                    name: (json["Names"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    image: json["Image"] as? String ?? "",
                    status: json["Status"] as? String ?? "",
                    state: parseState(json["State"] as? String ?? ""),
                    ports: json["Ports"] as? String ?? "",
                    createdAt: json["CreatedAt"] as? String ?? ""
                )
                loadedContainers.append(container)
            }
        }
        
        containers = loadedContainers.sorted { $0.name < $1.name }
    }
    
    private func loadImages() async {
        // docker images --format json
        let result = await runDockerCommand([
            "images",
            "--format", "{{json .}}"
        ])
        
        guard result.success else {
            return
        }
        
        var loadedImages: [DockerImage] = []
        
        for line in result.output.split(separator: "\n") {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let image = DockerImage(
                    id: json["ID"] as? String ?? "",
                    repository: json["Repository"] as? String ?? "",
                    tag: json["Tag"] as? String ?? "",
                    size: json["Size"] as? String ?? "",
                    createdAt: json["CreatedAt"] as? String ?? ""
                )
                loadedImages.append(image)
            }
        }
        
        images = loadedImages.sorted { $0.repository < $1.repository }
    }
    
    private func parseState(_ stateStr: String) -> ContainerState {
        let lower = stateStr.lowercased()
        if lower.contains("running") { return .running }
        if lower.contains("exited") { return .stopped }
        if lower.contains("paused") { return .paused }
        if lower.contains("restarting") { return .restarting }
        return .stopped
    }
    
    // MARK: - Container Actions
    
    func startContainer(_ container: DockerContainer) async {
        statusMessage = "Starting \(container.name)..."
        
        let result = await runDockerCommand(["start", container.id])
        
        if result.success {
            statusMessage = "\(container.name) started"
            await loadContainers()
        } else {
            statusMessage = "Failed to start container: \(result.output)"
        }
    }
    
    func stopContainer(_ container: DockerContainer) async {
        statusMessage = "Stopping \(container.name)..."
        
        let result = await runDockerCommand(["stop", container.id])
        
        if result.success {
            statusMessage = "\(container.name) stopped"
            await loadContainers()
        } else {
            statusMessage = "Failed to stop container: \(result.output)"
        }
    }
    
    func restartContainer(_ container: DockerContainer) async {
        statusMessage = "Restarting \(container.name)..."
        
        let result = await runDockerCommand(["restart", container.id])
        
        if result.success {
            statusMessage = "\(container.name) restarted"
            await loadContainers()
        } else {
            statusMessage = "Failed to restart container: \(result.output)"
        }
    }
    
    func removeContainer(_ container: DockerContainer) async {
        statusMessage = "Removing \(container.name)..."
        
        let result = await runDockerCommand(["rm", "-f", container.id])
        
        if result.success {
            statusMessage = "\(container.name) removed"
            await loadContainers()
        } else {
            statusMessage = "Failed to remove container: \(result.output)"
        }
    }
    
    func viewLogs(_ container: DockerContainer) async -> String {
        let result = await runDockerCommand(["logs", "--tail", "100", container.id])
        return result.output
    }
    
    func openInTerminal(_ container: DockerContainer) {
        let script = """
        tell application "Terminal"
            activate
            do script "docker exec -it \(container.id) /bin/sh || docker exec -it \(container.id) /bin/bash"
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                statusMessage = "Failed to open terminal: \(error)"
            }
        }
    }
    
    // MARK: - Docker Command Execution
    
    private func runDockerCommand(_ arguments: [String]) async -> (success: Bool, output: String) {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
            process.arguments = arguments
            
            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: data, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                let success = process.terminationStatus == 0
                let finalOutput = success ? output : errorOutput
                
                continuation.resume(returning: (success, finalOutput))
            } catch {
                continuation.resume(returning: (false, error.localizedDescription))
            }
        }
    }
}

// MARK: - Models

struct DockerContainer: Identifiable {
    let id: String
    let name: String
    let image: String
    let status: String
    let state: ContainerState
    let ports: String
    let createdAt: String
}

struct DockerImage: Identifiable {
    let id: String
    let repository: String
    let tag: String
    let size: String
    let createdAt: String
    
    var fullName: String {
        "\(repository):\(tag)"
    }
}

enum ContainerState {
    case running
    case stopped
    case paused
    case restarting
    
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .paused: return "Paused"
        case .restarting: return "Restarting"
        }
    }
    
    var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return .secondary
        case .paused: return .yellow
        case .restarting: return .orange
        }
    }
}

// MARK: - Docker Manager View

struct DockerManagerView: View {
    @ObservedObject var module: DockerManagerModule
    @State private var selectedTab: DockerTab = .containers
    @State private var selectedContainer: DockerContainer?
    @State private var showingLogs = false
    @State private var logs = ""
    
    enum DockerTab: String, CaseIterable {
        case containers = "Containers"
        case images = "Images"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.blue)
                Text(module.title)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    Task { await module.refresh() }
                } label: {
                    Image(systemName: module.isLoading ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                        .foregroundStyle(.secondary)
                        .symbolEffect(.rotate, isActive: module.isLoading)
                }
                .buttonStyle(.plain)
            }
            
            if !module.dockerAvailable {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Docker Not Available")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Make sure Docker Desktop is installed and running")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Status message
                if let message = module.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    ForEach(DockerTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                
                Divider()
                
                // Content
                Group {
                    if selectedTab == .containers {
                        containersView
                    } else {
                        imagesView
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .sheet(isPresented: $showingLogs) {
            LogsSheet(containerName: selectedContainer?.name ?? "", logs: logs)
        }
    }
    
    private var containersView: some View {
        Group {
            if module.containers.isEmpty {
                emptyStateView(icon: "shippingbox", text: "No containers")
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(module.containers) { container in
                            ContainerRow(
                                container: container,
                                onStart: { Task { await module.startContainer(container) } },
                                onStop: { Task { await module.stopContainer(container) } },
                                onRestart: { Task { await module.restartContainer(container) } },
                                onRemove: { Task { await module.removeContainer(container) } },
                                onLogs: {
                                    selectedContainer = container
                                    Task {
                                        logs = await module.viewLogs(container)
                                        showingLogs = true
                                    }
                                },
                                onTerminal: { module.openInTerminal(container) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
    
    private var imagesView: some View {
        Group {
            if module.images.isEmpty {
                emptyStateView(icon: "photo.stack", text: "No images")
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(module.images) { image in
                            ImageRow(image: image)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
    
    private func emptyStateView(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Container Row

struct ContainerRow: View {
    let container: DockerContainer
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onRemove: () -> Void
    let onLogs: () -> Void
    let onTerminal: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(container.state.color)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(container.image)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(container.state.displayName)
                    .font(.caption)
                    .foregroundStyle(container.state.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(container.state.color.opacity(0.1))
                    .cornerRadius(4)
            }
            
            if !container.ports.isEmpty {
                Text(container.ports)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 6) {
                if container.state == .running {
                    Button("Stop") { onStop() }
                        .controlSize(.mini)
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    
                    Button("Restart") { onRestart() }
                        .controlSize(.mini)
                        .buttonStyle(.bordered)
                } else {
                    Button("Start") { onStart() }
                        .controlSize(.mini)
                        .buttonStyle(.borderedProminent)
                }
                
                Button {
                    onLogs()
                } label: {
                    Image(systemName: "doc.text")
                }
                .controlSize(.mini)
                .buttonStyle(.bordered)
                .help("View logs")
                
                Button {
                    onTerminal()
                } label: {
                    Image(systemName: "terminal")
                }
                .controlSize(.mini)
                .buttonStyle(.bordered)
                .help("Open in Terminal")
                
                Spacer()
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Remove container")
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .alert("Remove Container?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { onRemove() }
        } message: {
            Text("Are you sure you want to remove '\(container.name)'?")
        }
    }
}

// MARK: - Image Row

struct ImageRow: View {
    let image: DockerImage
    
    var body: some View {
        HStack {
            Image(systemName: "photo")
                .foregroundStyle(.blue)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(image.fullName)
                    .font(.subheadline)
                Text("ID: \(image.id.prefix(12))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(image.size)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }
}

// MARK: - Logs Sheet

struct LogsSheet: View {
    let containerName: String
    let logs: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs: \(containerName)")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                Text(logs)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(width: 600, height: 400)
    }
}
