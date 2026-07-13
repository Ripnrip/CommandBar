# Implementation Checklist

Use this checklist to integrate the new WiFi, VM Manager, and Docker modules into your CommandBar app.

## Phase 1: Preparation ✅

- [ ] Read UPDATE_SUMMARY.md for an overview
- [ ] Read QUICK_INTEGRATION.md for code snippets
- [ ] Backup your current CommandBar.swift file
- [ ] Ensure you have macOS 14.0+ SDK

## Phase 2: Code Integration 🔧

### Update CommandBar.swift

- [ ] Open `CommandBar/CommandBar.swift`
- [ ] Add import statement: `import CoreWLAN`
- [ ] Add WiFi module initialization: `@StateObject private var wifiModule = WiFiModule()`
- [ ] Add VM module initialization: `@StateObject private var vmManagerModule = VMManagerModule()`
- [ ] Add Docker module initialization: `@StateObject private var dockerManagerModule = DockerManagerModule()`
- [ ] Comment out Jira module initialization: `// @StateObject private var jiraModule = JiraModule()`
- [ ] Find your module views section
- [ ] Add `WiFiModuleView(module: wifiModule)`
- [ ] Add `VMManagerView(module: vmManagerModule)`
- [ ] Add `DockerManagerView(module: dockerManagerModule)`
- [ ] Comment out or remove `JiraModuleView(module: jiraModule)`

### Update Refresh Logic (if applicable)

- [ ] Find your global refresh function (if you have one)
- [ ] Add `await wifiModule.refresh()` to refresh group
- [ ] Add `await vmManagerModule.refresh()` to refresh group
- [ ] Add `await dockerManagerModule.refresh()` to refresh group
- [ ] Remove or comment out Jira refresh

## Phase 3: Configuration ⚙️

### WiFi Configuration

- [ ] Open `CommandBar/Modules/WiFiModule.swift`
- [ ] Go to line ~88 in the `loadFavoriteNetworks()` function
- [ ] Replace default networks with your actual WiFi networks:
  ```swift
  favoriteNetworks = [
      WiFiNetwork(ssid: "YOUR_HOME_WIFI", password: "password", isPrimary: true),
      WiFiNetwork(ssid: "YOUR_OFFICE_WIFI", password: "password", isPrimary: false),
      // Add more as needed
  ]
  ```
- [ ] Save the file

### VM Manager Configuration

- [ ] Create VM directory: `mkdir -p ~/.vms`
- [ ] (Optional) If you want a different path, edit `VMManagerModule.swift` line ~22
- [ ] Place your VM bundles in the VM directory
- [ ] (Optional) Create `config.json` files in VM bundles for metadata

### Docker Configuration

- [ ] Install Docker Desktop for Mac (if not already installed)
- [ ] Start Docker Desktop
- [ ] Verify Docker is available: `which docker` (should show `/usr/local/bin/docker`)
- [ ] If docker is in a different location, update `DockerManagerModule.swift` line ~145

## Phase 4: Build & Test 🔨

### Build

- [ ] Run `swift package clean`
- [ ] Run `swift build`
- [ ] Check for build errors
- [ ] Fix any import or reference issues

### Test WiFi Module

- [ ] Launch the app: `swift run CommandBar`
- [ ] Verify WiFi module appears in the UI
- [ ] Check that it shows your current WiFi network
- [ ] Click the + button to add a favorite network
- [ ] Try connecting to a favorite network
- [ ] Verify disconnect functionality works
- [ ] Test removing a favorite network

### Test VM Manager Module

- [ ] Verify VM module appears in the UI
- [ ] Check that it lists VMs from ~/.vms/
- [ ] Create a test VM bundle if needed
- [ ] Try starting a VM
- [ ] Try stopping a VM
- [ ] Test the "Open in Finder" button
- [ ] (Optional) Test delete functionality with a test VM

### Test Docker Module

- [ ] Verify Docker module appears in the UI
- [ ] Check that it detects Docker Desktop
- [ ] Verify it lists your containers
- [ ] Test starting a stopped container
- [ ] Test stopping a running container
- [ ] Test the restart functionality
- [ ] Click "Logs" to view container logs
- [ ] Test the Terminal integration (exec into container)
- [ ] Switch to the Images tab and verify images are listed

### Test Jira Removal

- [ ] Verify Jira module does NOT appear in the UI
- [ ] Check console for any Jira-related errors (there should be none)
- [ ] Verify app doesn't try to initialize Jira module

## Phase 5: Polish & Deploy 🎨

### UI Adjustments

- [ ] Adjust module order in your view to your preference
- [ ] Customize colors if desired (search for `.foregroundStyle()`)
- [ ] Adjust spacing and padding to match your design
- [ ] Test with both light and dark mode

### Security (Recommended)

- [ ] Consider implementing Keychain storage for WiFi passwords
- [ ] Review the security section in INTEGRATION_GUIDE.md
- [ ] Update WiFiModule to use Keychain instead of UserDefaults

### Documentation

- [ ] Update any internal documentation
- [ ] Add notes about new modules to your personal docs
- [ ] Update any user guides or READMEs

### Installation

- [ ] Run `./install.sh` to install to ~/Applications/
- [ ] Verify the app launches on login (if configured)
- [ ] Test the installed version (not just `swift run`)

## Phase 6: Optional Enhancements 🚀

### WiFi Module

- [ ] Add signal strength indicators
- [ ] Implement auto-connect on app launch
- [ ] Add network speed testing
- [ ] Support for enterprise WiFi (802.1X)

### VM Manager

- [ ] Add real-time resource monitoring (CPU/RAM)
- [ ] Implement VM snapshot support
- [ ] Add VM cloning functionality
- [ ] Integrate with specific VM tools (UTM, Parallels, etc.)

### Docker Module

- [ ] Add Docker Compose support
- [ ] Implement volume management
- [ ] Add network inspection
- [ ] Show real-time container stats
- [ ] Add image pull/push functionality

### Keyboard Shortcuts

- [ ] Add ⌘⇧W for WiFi module
- [ ] Add ⌘⇧V for VM module
- [ ] Add ⌘⇧D for Docker module

### Menu Bar Indicators

- [ ] Show WiFi connection status in menu bar
- [ ] Show running container count in menu bar
- [ ] Show running VM count in menu bar

## Troubleshooting 🔍

If you encounter issues, check:

- [ ] All imports are present
- [ ] Module files are in correct locations
- [ ] Package.swift includes all source files
- [ ] No typos in module names
- [ ] Entitlements file is configured (if needed)
- [ ] WiFi is enabled on your Mac
- [ ] Docker Desktop is running (for Docker module)
- [ ] VM directory exists and has correct permissions

## Verification ✓

Final checks before considering complete:

- [ ] App builds without errors
- [ ] App runs without crashes
- [ ] All three new modules appear
- [ ] Jira module is gone
- [ ] WiFi connection works
- [ ] VM start/stop works (if you have VMs)
- [ ] Docker container management works (if you have Docker)
- [ ] No console errors on launch
- [ ] Memory usage is reasonable
- [ ] App responds quickly
- [ ] UI looks good in both light and dark mode

## Completion 🎉

Once all checkboxes are complete:

- [ ] Commit your changes to git
- [ ] Tag the release with a version number
- [ ] Update CHANGELOG.md with your changes
- [ ] Celebrate! You've successfully integrated three new modules! 🎊

---

## Quick Reference

**Key Files:**
- Main app: `CommandBar/CommandBar.swift`
- WiFi module: `CommandBar/Modules/WiFiModule.swift`
- VM module: `CommandBar/Modules/VMManagerModule.swift`
- Docker module: `CommandBar/Modules/DockerManagerModule.swift`
- Build config: `Package.swift`

**Key Commands:**
- Build: `swift build`
- Run: `swift run CommandBar`
- Install: `./install.sh`
- Clean: `swift package clean`

**Documentation:**
- Overview: `UPDATE_SUMMARY.md`
- Quick start: `QUICK_INTEGRATION.md`
- Detailed guide: `INTEGRATION_GUIDE.md`
- Architecture: `ARCHITECTURE.md`

**Need Help?**
Refer to the troubleshooting sections in INTEGRATION_GUIDE.md and QUICK_INTEGRATION.md.
