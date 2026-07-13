# CommandCenter

A macOS menu-bar command surface for personal productivity. Expands from a 28px strip into a full panel with modular cards for tasks, calendar, clipboard, search, web captures, and more.

## Overview

- Non-activating NSPanel strip (28 × 520px) that expands to ~75% screen height
- Module-based: each capability is an independent `CommandBarModule`
- Swift + SwiftUI, macOS 14+, Swift Package Manager
- Runs as a login item (`LSUIElement = true`)

## Modules

| Module | Status | Description |
|--------|--------|-------------|
| RemindersModule | Active | EventKit calendar + reminders |
| WiFiModule | Active | Quick WiFi network switching |
| VMManagerModule | Active | Apple VM management (start/stop/monitor) |
| DockerManagerModule | Active | Docker container & image management |
| ClipboardToolsModule | Active | Clipboard snippets manager |
| HackerNewsModule | Active | Top stories from HN |
| TerminalModule | Active | Terminal path detection & launch |
| DXSoundsRemoteModule | Active | Playback remote control |
| CareerModule | Active | LinkedIn/GitHub quick links |
| SpotlightModule | Active | System-wide search |
| JiraModule | Disabled | Issue search via Jira REST API |
| WebCaptureModule | Planned | Sync iOS web captures → Obsidian iCloud vault |

## WebCapture Integration

CommandCenter serves as the sync bridge between the Oracle Cloud capture server and your local Obsidian vault.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full pipeline.

**Flow:**
1. iPhone captures a page via SmartWebCapture iOS extension
2. Capture POSTed to Oracle Cloud server (203.0.113.10)
3. CommandCenter `WebCaptureModule` polls server every 2 min
4. New captures written to iCloud vault → synced to all devices

## Build & Run

```bash
# Build
swift build

# Run
swift run CommandBar

# Install as login item
./install.sh
```

## Project Structure

```
CommandCenter/
├── CommandBar/
│   └── CommandBar.swift      # Main app (5k+ lines, modular design)
├── Package.swift
├── CommandBar.plist           # Launch agent plist
├── install.sh                 # Login item installer
├── README.md
├── CHANGELOG.md
├── Features.md
└── ARCHITECTURE.md
```

## Configuration

Environment variables (set in shell profile or `.env`):

| Variable | Description |
|----------|-------------|
| `ORACLE_SERVER_URL` | Oracle Cloud server base URL (for WebCaptureModule) |
| `ORACLE_API_KEY` | API key for oracle-tasks-server |
| `OBSIDIAN_VAULT_PATH` | Full path to Obsidian iCloud vault |
| `WEBCAPTURE_POLL_INTERVAL` | Poll interval in seconds (default: 120) |

## Requirements

- macOS 14.0+
- Swift 5.9+
- Xcode 15+ or Swift toolchain
