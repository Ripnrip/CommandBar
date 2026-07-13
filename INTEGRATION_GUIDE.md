# Integration Guide for New Modules

This guide explains how to integrate the new WiFi, VM Manager, and Docker modules into your CommandBar app, and how to hide/disable the Jira module.

## Overview of New Modules

### 1. WiFiModule
- **Purpose**: Quickly connect to your favorite WiFi networks
- **Features**:
  - View current WiFi connection status
  - Save favorite networks with passwords
  - One-click connection to saved networks
  - Scan for available networks
  - Disconnect from current network
  - Manage favorites (add/remove)

### 2. VMManagerModule  
- **Purpose**: Manage Apple VMs (macOS Virtualization framework compatible)
- **Features**:
  - List all VMs in ~/.vms/ directory
  - Start/stop virtual machines
  - View VM specs (CPU, RAM, disk)
  - Delete VMs with confirmation
  - Open VM folder in Finder
  - Support for VM bundles and config files

### 3. DockerManagerModule
- **Purpose**: Manage Docker containers and images
- **Features**:
  - List all containers with status
  - Start/stop/restart containers
  - Remove containers
  - View container logs
  - Open container shell in Terminal
  - View Docker images
  - Auto-detect Docker availability

## Integration Steps

### Step 1: Add the Module Files

The following files have been created in `/repo/CommandBar/Modules/`:
- `WiFiModule.swift`
- `VMManagerModule.swift`
- `DockerManagerModule.swift`

### Step 2: Update Package.swift

Update your Package.swift to include the new module files:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CommandBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "CommandBar",
            targets: ["CommandBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CommandBar",
            path: "CommandBar",
            exclude: [
                ".DS_Store"
            ],
            sources: [
                "CommandBar.swift",
                "Modules/WiFiModule.swift",
                "Modules/VMManagerModule.swift",
                "Modules/DockerManagerModule.swift"
            ],
            swiftSettings: [
                .define("COMMANDBAR_APP")
            ]
        )
    ]
)
```

### Step 3: Update CommandBar.swift

In your main `CommandBar.swift` file, you'll need to:

#### 3.1 Import Required Frameworks

Add these imports if not already present:
```swift
import CoreWLAN
import Virtualization
```

#### 3.2 Initialize New Modules

Find where you initialize modules (likely in your app's main struct or a module manager). Add:

```swift
@StateObject private var wifiModule = WiFiModule()
@StateObject private var vmManagerModule = VMManagerModule()
@StateObject private var dockerManagerModule = DockerManagerModule()
```

#### 3.3 Comment Out or Remove Jira Module

Find where JiraModule is initialized and comment it out:
```swift
// @StateObject private var jiraModule = JiraModule()
```

#### 3.4 Update Your Module List/UI

In your SwiftUI view where modules are displayed, replace the JiraModule view with the new modules:

```swift
// REMOVE OR COMMENT OUT:
// JiraModuleView(module: jiraModule)

// ADD:
WiFiModuleView(module: wifiModule)
VMManagerView(module: vmManagerModule)  
DockerManagerView(module: dockerManagerModule)
```

### Step 4: Required Entitlements

#### For WiFi Module:
Add to your app's entitlements (if you don't have an entitlements file, create one):

**CommandBar.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

**Note:** WiFi network manipulation requires system-level access, so the app needs to run without sandboxing.

#### For Docker Module:
No special entitlements required, but Docker Desktop must be installed and running.

## Configuration

### WiFi Module Configuration

Favorite networks are stored in UserDefaults. To customize the default favorites, edit the `loadFavoriteNetworks()` method in WiFiModule.swift:

```swift
favoriteNetworks = [
    WiFiNetwork(ssid: "Your Home Network", password: "password123", isPrimary: true),
    WiFiNetwork(ssid: "Your Office Network", password: "password456", isPrimary: false),
    WiFiNetwork(ssid: "Your Phone Hotspot", password: "", isPrimary: false)
]
```

Users can also add/remove favorites through the UI.

### VM Manager Configuration

By default, VMs are expected in `~/.vms/` directory. To change this, edit the init in VMManagerModule.swift:

```swift
// Change this path to your preferred VM directory
self.vmDirectory = home.appendingPathComponent("your/custom/path")
```

VM bundles should contain a `config.json` file with this structure:
```json
{
  "name": "macOS Sonoma",
  "cpuCount": 4,
  "memorySize": 8589934592,
  "diskSize": 68719476736
}
```

### Docker Module Configuration

Docker commands are executed via `/usr/local/bin/docker`. If your Docker binary is in a different location, update the path in `runDockerCommand()`:

```swift
process.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
// Change to your Docker path if different
```

## Testing

### Test WiFi Module:
1. Launch the app
2. The WiFi module should show your current connection
3. Click the + button to add a favorite network
4. Click "Connect" to test connection

### Test VM Manager:
1. Create test VM bundle in ~/.vms/
2. Add a config.json file
3. The VM should appear in the list
4. Test start/stop functionality

### Test Docker Module:
1. Ensure Docker Desktop is running
2. Create some test containers: `docker run -d nginx`
3. The module should list your containers
4. Test start/stop/logs functionality

## Troubleshooting

### WiFi Module Issues:
- **"WiFi interface not available"**: Make sure WiFi is enabled in System Settings
- **Can't connect**: Verify the password is correct and the network is in range
- **Permission denied**: The app needs to run without sandboxing

### VM Manager Issues:
- **VMs not appearing**: Check that VM bundles are in ~/.vms/ directory
- **Can't start VM**: Verify the VM bundle structure and config.json format

### Docker Module Issues:
- **"Docker Not Available"**: Install Docker Desktop and ensure it's running
- **Commands fail**: Check that `/usr/local/bin/docker` exists or update the path
- **Permission errors**: You may need to add your user to the docker group

## Customization

### Styling
All modules use SwiftUI's standard colors and styling. To customize:
- Colors: Modify `.foregroundStyle()` and `.background()` calls
- Fonts: Adjust `.font()` modifiers
- Spacing: Change padding and spacing values

### Adding Features

#### WiFi Module:
- Add signal strength indicator
- Support for enterprise WiFi (802.1X)
- Network speed testing

#### VM Manager:
- Snapshot management
- VM cloning
- Resource monitoring (CPU/RAM usage)

#### Docker Module:
- Docker Compose support
- Volume management
- Network inspection
- Container stats (CPU/memory usage)

## Security Considerations

### WiFi Passwords
Passwords are currently stored in UserDefaults as plain text. For production use, consider:
1. Using Keychain to store passwords securely
2. Encrypting stored credentials
3. Implementing a master password

Example Keychain integration:
```swift
import Security

func saveToKeychain(service: String, account: String, password: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecValueData as String: password.data(using: .utf8)!
    ]
    SecItemAdd(query as CFDictionary, nil)
}
```

## Next Steps

1. Build and test each module individually
2. Customize default settings (WiFi networks, VM paths)
3. Add any custom styling to match your app's design
4. Consider adding keyboard shortcuts for common actions
5. Update Features.md and ARCHITECTURE.md with the new modules

## Updating Documentation

Update your Features.md:
```markdown
- [x] **WiFiModule** — Quick WiFi network switching
- [x] **VMManagerModule** — Apple VM management  
- [x] **DockerManagerModule** — Docker container management
- [ ] **JiraModule** — (Disabled) Issue search via Jira REST API
```

Update your ARCHITECTURE.md with the new module descriptions.
