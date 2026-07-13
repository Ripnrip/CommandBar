import SwiftUI
import Virtualization
import Foundation

// MARK: - VM Manager Module

@MainActor
class VMManagerModule: ObservableObject {
    @Published var virtualMachines: [VirtualMachineInfo] = []
    @Published var isLoading: Bool = false
    @Published var statusMessage: String?
    
    var title: String { "Virtual Machines" }
    
    private let vmDirectory: URL
    
    init() {
        // Default VM directory - customize as needed
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.vmDirectory = home.appendingPathComponent(".vms")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: vmDirectory, withIntermediateDirectories: true)
        
        Task {
            await refresh()
        }
    }
    
    func refresh() async {
        isLoading = true
        statusMessage = nil
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: vmDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var vms: [VirtualMachineInfo] = []
            
            for url in contents {
                // Look for .bundle directories or specific VM configurations
                if url.pathExtension == "bundle" || url.lastPathComponent.contains("VM") {
                    let configFile = url.appendingPathComponent("config.json")
                    
                    if FileManager.default.fileExists(atPath: configFile.path) {
                        if let data = try? Data(contentsOf: configFile),
                           let config = try? JSONDecoder().decode(VMConfig.self, from: data) {
                            
                            let info = VirtualMachineInfo(
                                id: UUID(),
                                name: config.name,
                                bundlePath: url,
                                cpuCount: config.cpuCount,
                                memorySize: config.memorySize,
                                diskSize: config.diskSize,
                                state: .stopped
                            )
                            vms.append(info)
                        }
                    } else {
                        // Create a basic VM info from directory name
                        let info = VirtualMachineInfo(
                            id: UUID(),
                            name: url.deletingPathExtension().lastPathComponent,
                            bundlePath: url,
                            cpuCount: 2,
                            memorySize: 4 * 1024 * 1024 * 1024,
                            diskSize: 64 * 1024 * 1024 * 1024,
                            state: .stopped
                        )
                        vms.append(info)
                    }
                }
            }
            
            virtualMachines = vms.sorted { $0.name < $1.name }
        } catch {
            statusMessage = "Failed to load VMs: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func startVM(_ vm: VirtualMachineInfo) async {
        statusMessage = "Starting \(vm.name)..."
        
        // Update state
        if let index = virtualMachines.firstIndex(where: { $0.id == vm.id }) {
            virtualMachines[index].state = .starting
        }
        
        do {
            // Use shell command to start VM
            // This is a placeholder - you'd integrate with your actual VM management tool
            // For example: macOS Virtualization framework, UTM, or custom scripts
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [vm.bundlePath.path]
            
            try process.run()
            process.waitUntilExit()
            
            if let index = virtualMachines.firstIndex(where: { $0.id == vm.id }) {
                virtualMachines[index].state = .running
            }
            
            statusMessage = "\(vm.name) started"
        } catch {
            statusMessage = "Failed to start VM: \(error.localizedDescription)"
            if let index = virtualMachines.firstIndex(where: { $0.id == vm.id }) {
                virtualMachines[index].state = .stopped
            }
        }
    }
    
    func stopVM(_ vm: VirtualMachineInfo) async {
        statusMessage = "Stopping \(vm.name)..."
        
        if let index = virtualMachines.firstIndex(where: { $0.id == vm.id }) {
            virtualMachines[index].state = .stopping
        }
        
        // Implement VM stopping logic
        // This would integrate with your VM management system
        
        try? await Task.sleep(for: .seconds(1))
        
        if let index = virtualMachines.firstIndex(where: { $0.id == vm.id }) {
            virtualMachines[index].state = .stopped
        }
        
        statusMessage = "\(vm.name) stopped"
    }
    
    func deleteVM(_ vm: VirtualMachineInfo) async {
        statusMessage = "Deleting \(vm.name)..."
        
        do {
            try FileManager.default.removeItem(at: vm.bundlePath)
            virtualMachines.removeAll { $0.id == vm.id }
            statusMessage = "\(vm.name) deleted"
        } catch {
            statusMessage = "Failed to delete VM: \(error.localizedDescription)"
        }
    }
    
    func openVMFolder(_ vm: VirtualMachineInfo) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: vm.bundlePath.path)
    }
}

// MARK: - Models

struct VirtualMachineInfo: Identifiable {
    let id: UUID
    let name: String
    let bundlePath: URL
    let cpuCount: Int
    let memorySize: UInt64
    let diskSize: UInt64
    var state: VMState
    
    var memoryGB: Double {
        Double(memorySize) / (1024 * 1024 * 1024)
    }
    
    var diskGB: Double {
        Double(diskSize) / (1024 * 1024 * 1024)
    }
}

enum VMState {
    case stopped
    case starting
    case running
    case stopping
    case paused
    case error
    
    var displayName: String {
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting..."
        case .running: return "Running"
        case .stopping: return "Stopping..."
        case .paused: return "Paused"
        case .error: return "Error"
        }
    }
    
    var color: Color {
        switch self {
        case .stopped: return .secondary
        case .starting: return .orange
        case .running: return .green
        case .stopping: return .orange
        case .paused: return .yellow
        case .error: return .red
        }
    }
}

struct VMConfig: Codable {
    let name: String
    let cpuCount: Int
    let memorySize: UInt64
    let diskSize: UInt64
}

// MARK: - VM Manager View

struct VMManagerView: View {
    @ObservedObject var module: VMManagerModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "server.rack")
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
            
            // Status message
            if let message = module.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            }
            
            Divider()
            
            // VM List
            if module.virtualMachines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No virtual machines found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Place VM bundles in ~/.vms/")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(module.virtualMachines) { vm in
                            VMRow(
                                vm: vm,
                                onStart: { Task { await module.startVM(vm) } },
                                onStop: { Task { await module.stopVM(vm) } },
                                onDelete: { Task { await module.deleteVM(vm) } },
                                onOpenFolder: { module.openVMFolder(vm) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - VM Row

struct VMRow: View {
    let vm: VirtualMachineInfo
    let onStart: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void
    let onOpenFolder: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // State indicator
                Circle()
                    .fill(vm.state.color)
                    .frame(width: 8, height: 8)
                
                Text(vm.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // State label
                Text(vm.state.displayName)
                    .font(.caption)
                    .foregroundStyle(vm.state.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(vm.state.color.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // VM specs
            HStack(spacing: 12) {
                Label("\(vm.cpuCount) CPU", systemImage: "cpu")
                Label(String(format: "%.1f GB", vm.memoryGB), systemImage: "memorychip")
                Label(String(format: "%.0f GB", vm.diskGB), systemImage: "internaldrive")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Actions
            HStack(spacing: 8) {
                if vm.state == .running {
                    Button("Stop") {
                        onStop()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.orange)
                } else if vm.state == .stopped {
                    Button("Start") {
                        onStart()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Button {
                    onOpenFolder()
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Show in Finder")
                
                Spacer()
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Delete VM")
                .disabled(vm.state == .running)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .alert("Delete VM?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(vm.name)'? This cannot be undone.")
        }
    }
}
