# CommandCenter — Architecture

## Overview

CommandCenter is a macOS menu-bar application built with Swift + SwiftUI. It exposes a non-activating strip panel that expands into a full command surface. Each capability is a self-contained `CommandBarModule` (ObservableObject) polled on a timer or event.

---

## System Architecture

### WebCapture Sync Pipeline

```
iPhone Safari (SmartWebCapture iOS Extension)
    │
    │  POST /capture  (Bearer auth, JSON payload)
    │  POST /capture-session
    │  POST /export-bookmarks
    ▼
Oracle Cloud Server — 203.0.113.10
    Traefik (reverse proxy, HTTPS, rate limiting)
    └─ FastAPI Python server (oracle-tasks-server)
         ├── POST /capture          → build markdown, queue in ~/captures/pending/
         ├── POST /capture-session  → session note, queued
         ├── POST /export-bookmarks → bookmarks note, queued
         ├── GET  /captures/pending → list unsynced files (JSON manifest)
         └── POST /captures/ack    → mark files as synced, move to ~/captures/synced/
    │
    │  GET /captures/pending  (every 2 min)
    │  POST /captures/ack     (after writing)
    ▼
CommandCenter — WebCaptureModule (macOS, Swift)
    ├── Polls oracle server every 2 min
    ├── Downloads pending markdown content
    ├── Writes files to iCloud vault path
    └── Updates menu-bar sync status
    │
    ▼
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Brain-System/WebClips/
    ├── archive/
    ├── latest/
    ├── sessions/
    └── bookmarks/
    │
    ▼  iCloud Drive sync
All devices (iPhone, iPad, Mac)
```

---

## Module Architecture

Each module conforms to `CommandBarModule`:

```swift
protocol CommandBarModule: ObservableObject {
    var title: String { get }
    func refresh() async
}
```

Modules loaded at startup, each managing its own async refresh lifecycle via structured concurrency (`Task`, `Task.sleep`).

### Existing Modules

| Module | Purpose | Data Source |
|--------|---------|-------------|
| TerminalModule | Terminal path detection & launch | Local filesystem |
| WiFiModule | Quick WiFi network switching | CoreWLAN, UserDefaults |
| VMManagerModule | Apple VM management | Local filesystem (~/.vms/) |
| DockerManagerModule | Docker container/image management | Docker CLI |
| RemindersModule | Calendar & reminders | EventKit |
| ClipboardToolsModule | Clipboard snippets | NSPasteboard |
| HackerNewsModule | Top stories | Firebase API |
| DXSoundsRemoteModule | Playback control | Local AppleScript |
| CareerModule | Quick links | Static config |
| SpotlightModule | System search | Spotlight API |
| JiraModule (disabled) | Issue search | Jira REST API |

### Planned Modules

| Module | Purpose | Data Source |
|--------|---------|-------------|
| WebCaptureModule | Sync iOS web captures → iCloud vault | Oracle Cloud server |

---

## WebCaptureModule Design

```
WebCaptureModule
├── pollInterval: 2 min (configurable via env/settings)
├── serverURL: http://203.0.113.10 (Traefik-routed)
├── apiKey: from Keychain or env
├── vaults: [VaultConfig]          ← loaded from ~/.config/commandcenter/vaults.json
└── State
    ├── lastSync: Date?
    ├── pendingCount: Int
    └── status: .idle | .syncing | .error(String)

Flow:
  1. GET /captures/vaults           → list vaults with pending counts
  2. For each vault with pending > 0:
     GET /captures/pending?vault=<name> → [CaptureFile]
     resolve local path via vaults.json (fallback: default vault path)
     write markdown to localPath/WebClips/<subdir>/
     POST /captures/ack { vault, ids }
  3. Update lastSync + total pending count in menu bar
```

### Vault Configuration

`~/.config/commandcenter/vaults.json`:

```json
{
  "vaults": [
    {
      "name": "default",
      "path": "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Brain-System",
      "description": "Main personal vault"
    },
    {
      "name": "work",
      "path": "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Work",
      "description": "Work vault"
    }
  ]
}
```

- `name` matches the `vault` field sent from the iOS extension settings
- Unknown vault names fall back to the `default` entry
- `vaults.example.json` in the repo is the starting-point config

---

## Infrastructure

- **Platform:** macOS 14.0+
- **Build:** Swift Package Manager
- **UI:** SwiftUI + AppKit (NSPanel)
- **Concurrency:** Swift structured concurrency (async/await, Task)
- **Networking:** URLSession with 10s timeout
- **Auth storage:** macOS Keychain (planned)

---

## Oracle Cloud Server

See `~/oracle-tasks-server/` on the Oracle Cloud instance (203.0.113.10).

- **Runtime:** Python 3 + FastAPI + Uvicorn
- **Proxy:** Traefik v3 (HTTPS, rate limiting, metrics)
- **Auth:** X-API-Key header (HMAC constant-time comparison)
- **Observability:** Prometheus metrics at `:9090`

---

## Data Flow: Capture Payload

```json
{
  "title": "Page Title",
  "url": "https://example.com/article",
  "timestamp": "2026-04-12T10:00:00.000Z",
  "source": "ios-safari-extension",
  "tags": ["ai", "site/example.com"],
  "description": "Meta description",
  "summary": "Auto-generated 280-char summary",
  "keywords": ["keyword1", "keyword2"],
  "headings": ["H1 title", "H2 section"],
  "content": "First 1500 chars of page text",
  "highlights": ["Notable sentence 1", "Notable sentence 2"],
  "thoughts": []
}
```

Output markdown written to:
- `WebClips/archive/<timestamp> - <slug> - <hash>.md`
- `WebClips/latest/<slug> - latest - <hash>.md`
- `WebClips/sessions/<timestamp> - session.md`
- `WebClips/bookmarks/<timestamp> - bookmarks-export.md`
