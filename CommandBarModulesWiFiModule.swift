import SwiftUI
import CoreWLAN

// MARK: - WiFi Module

@MainActor
class WiFiModule: ObservableObject {
    @Published var currentNetwork: String?
    @Published var isConnected: Bool = false
    @Published var favoriteNetworks: [WiFiNetwork] = []
    @Published var availableNetworks: [CWNetwork] = []
    @Published var isScanning: Bool = false
    @Published var statusMessage: String?
    
    private var wifiClient: CWWiFiClient?
    private var wifiInterface: CWInterface?
    
    var title: String { "WiFi" }
    
    init() {
        self.wifiClient = CWWiFiClient.shared()
        self.wifiInterface = wifiClient?.interface()
        loadFavoriteNetworks()
        Task {
            await refresh()
        }
    }
    
    func refresh() async {
        await updateCurrentNetwork()
        await scanNetworks()
    }
    
    @MainActor
    private func updateCurrentNetwork() async {
        guard let interface = wifiInterface else { return }
        
        if let ssid = interface.ssid() {
            currentNetwork = ssid
            isConnected = true
        } else {
            currentNetwork = nil
            isConnected = false
        }
    }
    
    @MainActor
    func scanNetworks() async {
        isScanning = true
        statusMessage = nil
        
        guard let interface = wifiInterface else {
            statusMessage = "WiFi interface not available"
            isScanning = false
            return
        }
        
        do {
            let networks = try interface.scanForNetworks(withSSID: nil)
            availableNetworks = Array(networks).sorted { n1, n2 in
                (n1.rssiValue) > (n2.rssiValue)
            }
        } catch {
            statusMessage = "Scan failed: \(error.localizedDescription)"
        }
        
        isScanning = false
    }
    
    func connect(to network: WiFiNetwork) async {
        statusMessage = "Connecting to \(network.ssid)..."
        
        guard let interface = wifiInterface else {
            statusMessage = "WiFi interface not available"
            return
        }
        
        do {
            // Find the network in available networks
            if let cwNetwork = availableNetworks.first(where: { $0.ssid == network.ssid }) {
                try interface.associate(to: cwNetwork, password: network.password)
                statusMessage = "Connected to \(network.ssid)"
                await updateCurrentNetwork()
            } else {
                statusMessage = "Network '\(network.ssid)' not found"
            }
        } catch {
            statusMessage = "Connection failed: \(error.localizedDescription)"
        }
    }
    
    func disconnect() async {
        guard let interface = wifiInterface else { return }
        interface.disassociate()
        await updateCurrentNetwork()
        statusMessage = "Disconnected"
    }
    
    func addToFavorites(_ network: WiFiNetwork) {
        if !favoriteNetworks.contains(where: { $0.ssid == network.ssid }) {
            favoriteNetworks.append(network)
            saveFavoriteNetworks()
        }
    }
    
    func removeFromFavorites(_ network: WiFiNetwork) {
        favoriteNetworks.removeAll { $0.ssid == network.ssid }
        saveFavoriteNetworks()
    }
    
    private func loadFavoriteNetworks() {
        // Load from UserDefaults or a config file
        if let data = UserDefaults.standard.data(forKey: "favoriteWiFiNetworks"),
           let decoded = try? JSONDecoder().decode([WiFiNetwork].self, from: data) {
            favoriteNetworks = decoded
        } else {
            // Default favorite networks - customize these!
            favoriteNetworks = [
                WiFiNetwork(ssid: "Home WiFi", password: "", isPrimary: true),
                WiFiNetwork(ssid: "Office WiFi", password: "", isPrimary: false),
                WiFiNetwork(ssid: "iPhone Hotspot", password: "", isPrimary: false)
            ]
        }
    }
    
    private func saveFavoriteNetworks() {
        if let encoded = try? JSONEncoder().encode(favoriteNetworks) {
            UserDefaults.standard.set(encoded, forKey: "favoriteWiFiNetworks")
        }
    }
}

// MARK: - WiFi Network Model

struct WiFiNetwork: Codable, Identifiable {
    let id = UUID()
    var ssid: String
    var password: String
    var isPrimary: Bool
    
    enum CodingKeys: String, CodingKey {
        case ssid, password, isPrimary
    }
}

// MARK: - WiFi Module View

struct WiFiModuleView: View {
    @ObservedObject var module: WiFiModule
    @State private var showingAddNetwork = false
    @State private var newSSID = ""
    @State private var newPassword = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: isConnected ? "wifi" : "wifi.slash")
                    .foregroundStyle(isConnected ? .green : .secondary)
                Text(module.title)
                    .font(.headline)
                Spacer()
                Button {
                    Task { await module.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Current network status
            if let current = module.currentNetwork {
                HStack {
                    Text("Connected:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(current)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Button("Disconnect") {
                        Task { await module.disconnect() }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            
            // Status message
            if let message = module.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            }
            
            Divider()
            
            // Favorite networks
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Favorites")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button {
                        showingAddNetwork = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                if module.favoriteNetworks.isEmpty {
                    Text("No favorite networks")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(module.favoriteNetworks) { network in
                        WiFiNetworkRow(
                            network: network,
                            isConnected: network.ssid == module.currentNetwork,
                            onConnect: {
                                Task { await module.connect(to: network) }
                            },
                            onRemove: {
                                module.removeFromFavorites(network)
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .sheet(isPresented: $showingAddNetwork) {
            AddWiFiNetworkSheet(
                ssid: $newSSID,
                password: $newPassword,
                onSave: {
                    let network = WiFiNetwork(ssid: newSSID, password: newPassword, isPrimary: false)
                    module.addToFavorites(network)
                    showingAddNetwork = false
                    newSSID = ""
                    newPassword = ""
                },
                onCancel: {
                    showingAddNetwork = false
                    newSSID = ""
                    newPassword = ""
                }
            )
        }
    }
    
    private var isConnected: Bool {
        module.currentNetwork != nil
    }
}

// MARK: - WiFi Network Row

struct WiFiNetworkRow: View {
    let network: WiFiNetwork
    let isConnected: Bool
    let onConnect: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: network.isPrimary ? "star.fill" : "wifi")
                .foregroundStyle(isConnected ? .green : .secondary)
                .frame(width: 16)
            
            Text(network.ssid)
                .font(.subheadline)
                .fontWeight(isConnected ? .semibold : .regular)
            
            Spacer()
            
            if isConnected {
                Text("Connected")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            } else {
                Button("Connect") {
                    onConnect()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Remove from favorites")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isConnected ? Color.green.opacity(0.05) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Add Network Sheet

struct AddWiFiNetworkSheet: View {
    @Binding var ssid: String
    @Binding var password: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add WiFi Network")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Network Name (SSID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("WiFi network name", text: $ssid)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Network password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ssid.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
