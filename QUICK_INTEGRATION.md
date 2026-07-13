# Quick Integration Code Snippets

## 1. Add These Imports (Top of CommandBar.swift)

```swift
import CoreWLAN        // For WiFi module
import Virtualization  // For VM manager (optional, currently using shell commands)
```

## 2. Initialize the New Modules

Add these alongside your other module @StateObject declarations:

```swift
@StateObject private var wifiModule = WiFiModule()
@StateObject private var vmManagerModule = VMManagerModule()
@StateObject private var dockerManagerModule = DockerManagerModule()
```

## 3. Comment Out Jira Module

Find and comment out the Jira module:

```swift
// DISABLE JIRA MODULE
// @StateObject private var jiraModule = JiraModule()
```

## 4. Add Module Views to Your UI

In your main content view where modules are displayed, add:

```swift
// NEW: WiFi Module - replaces Jira
WiFiModuleView(module: wifiModule)

// NEW: VM Manager
VMManagerView(module: vmManagerModule)

// NEW: Docker Manager  
DockerManagerView(module: dockerManagerModule)

// REMOVE OR COMMENT OUT:
// JiraModuleView(module: jiraModule)
```

## 5. Example Complete Module List

Here's what a typical module list might look like in your UI:

```swift
var body: some View {
    ScrollView {
        VStack(spacing: 12) {
            // Quick Actions / System
            WiFiModuleView(module: wifiModule)
            TerminalModuleView(module: terminalModule)
            SpotlightModuleView(module: spotlightModule)
            
            // Development Tools
            DockerManagerView(module: dockerManagerModule)
            VMManagerView(module: vmManagerModule)
            
            // Productivity
            RemindersModuleView(module: remindersModule)
            ClipboardToolsModuleView(module: clipboardToolsModule)
            
            // Content & Links
            HackerNewsModuleView(module: hackerNewsModule)
            CareerModuleView(module: careerModule)
            
            // Media
            DXSoundsRemoteModuleView(module: dxSoundsRemoteModule)
            
            // DISABLED - Jira Module
            // JiraModuleView(module: jiraModule)
        }
        .padding()
    }
}
```

## 6. Cleanup Tasks

### Remove Jira-related code:
1. Comment out JiraModule initialization
2. Comment out JiraModuleView in your UI
3. Optionally delete or move JiraModule.swift to an "Archive" folder

### Update refresh logic:
If you have a global refresh function, update it:

```swift
func refreshAllModules() async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask { await self.wifiModule.refresh() }
        group.addTask { await self.vmManagerModule.refresh() }
        group.addTask { await self.dockerManagerModule.refresh() }
        group.addTask { await self.remindersModule.refresh() }
        group.addTask { await self.clipboardToolsModule.refresh() }
        group.addTask { await self.hackerNewsModule.refresh() }
        // ... other modules
        
        // REMOVED: Jira refresh
        // group.addTask { await self.jiraModule.refresh() }
    }
}
```

## 7. Keyboard Shortcuts (Optional)

Add keyboard shortcuts for quick access:

```swift
.keyboardShortcut("w", modifiers: [.command, .shift])  // WiFi
.keyboardShortcut("v", modifiers: [.command, .shift])  // VMs  
.keyboardShortcut("d", modifiers: [.command, .shift])  // Docker
```

Example in context:

```swift
Button("Show WiFi") {
    // Focus or show WiFi module
}
.keyboardShortcut("w", modifiers: [.command, .shift])
```

## 8. Module Protocol Conformance

If you have a CommandBarModule protocol, ensure the new modules conform:

```swift
protocol CommandBarModule: ObservableObject {
    var title: String { get }
    func refresh() async
}

// All three new modules already conform to this pattern:
// - WiFiModule has title and refresh() async
// - VMManagerModule has title and refresh() async  
// - DockerManagerModule has title and refresh() async
```

## 9. Menu Bar Status (Optional)

Add status indicators to your menu bar for quick info:

```swift
// In your menu bar view
HStack(spacing: 16) {
    // WiFi status
    if wifiModule.isConnected {
        Image(systemName: "wifi")
            .foregroundStyle(.green)
    } else {
        Image(systemName: "wifi.slash")
            .foregroundStyle(.secondary)
    }
    
    // Docker status
    if dockerManagerModule.dockerAvailable {
        Image(systemName: "shippingbox.fill")
            .foregroundStyle(.blue)
            .badge(dockerManagerModule.containers.filter { $0.state == .running }.count)
    }
    
    // VM status
    let runningVMs = vmManagerModule.virtualMachines.filter { $0.state == .running }.count
    if runningVMs > 0 {
        Image(systemName: "server.rack")
            .foregroundStyle(.green)
            .badge(runningVMs)
    }
}
```

## 10. Environment Variables (Optional)

If you want to make paths configurable via environment variables:

```swift
// For VM Manager
let vmPath = ProcessInfo.processInfo.environment["VM_DIRECTORY"] 
    ?? "~/.vms"

// For Docker
let dockerPath = ProcessInfo.processInfo.environment["DOCKER_PATH"] 
    ?? "/usr/local/bin/docker"
```

## 11. Build & Run

```bash
# Clean build
swift package clean

# Build with the new modules
swift build

# Run
swift run CommandBar

# Or use the installer
./install.sh
```

## 12. Verification Checklist

After integration, verify:

- [ ] App builds without errors
- [ ] WiFi module shows current network
- [ ] Can add favorite WiFi networks
- [ ] VM manager shows VMs in ~/.vms/
- [ ] Docker module detects Docker Desktop
- [ ] Docker module lists containers
- [ ] Jira module is no longer visible in UI
- [ ] No build warnings related to new modules
- [ ] App launches without crashes

## Common Build Issues

### Issue: "Cannot find 'CWWiFiClient' in scope"
**Solution:** Add `import CoreWLAN` at the top of CommandBar.swift

### Issue: "Module 'Virtualization' not found"  
**Solution:** 
1. This is only needed if using the Virtualization framework directly
2. Currently the VM module uses shell commands, so this import is optional
3. If not using it, you can remove the import

### Issue: New module files not found
**Solution:** 
1. Check that files are in CommandBar/Modules/ directory
2. Verify Package.swift sources array includes the new files
3. Run `swift package clean` and rebuild

### Issue: WiFi module crashes on network scan
**Solution:**
1. Ensure app is not sandboxed (check entitlements)
2. Verify WiFi is enabled in System Settings
3. Run app with administrator privileges if needed

## Next Steps

1. Customize favorite WiFi networks
2. Set up your VM directory structure
3. Test with actual Docker containers
4. Update your documentation (Features.md, ARCHITECTURE.md)
5. Consider adding these enhancements:
   - Keychain integration for WiFi passwords
   - VM snapshot support
   - Docker Compose integration
   - Network speed testing for WiFi
