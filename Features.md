# CommandCenter — Features

---

## Implemented

### UI & Shell
- [x] Menu-bar strip panel (28px tall, 520px wide, non-activating)
- [x] Expandable panel (~75% screen height on click)
- [x] Design token system (colors, spacing, typography, radii)
- [x] Spring animations with staggered entrance delays
- [x] Runs without Dock icon (`LSUIElement`)
- [x] Login item auto-launch via `ServiceManagement`

### Modules
- [x] **RemindersModule** — EventKit calendar + reminders (incremental + full fetch)
- [x] **WiFiModule** — quick WiFi network switching for favorite networks
- [x] **VMManagerModule** — Apple VM management (start/stop/monitor)
- [x] **DockerManagerModule** — Docker container and image management
- [x] **ClipboardToolsModule** — clipboard snippet storage and recall
- [x] **HackerNewsModule** — top stories feed
- [x] **TerminalModule** — path detection, terminal launch shortcuts
- [x] **DXSoundsRemoteModule** — playback remote via AppleScript
- [x] **CareerModule** — LinkedIn/GitHub quick links
- [x] **SpotlightModule** — system-wide search
- [x] **ShowcaseModule** — UI component showcase
- [ ] **JiraModule** — (DISABLED) issue search via Jira Cloud REST API

### Networking
- [x] Generic `fetch<T: Decodable>()` for typed API responses
- [x] 10s URLSession timeout
- [x] Async/await structured concurrency throughout

---

## Planned

### WebCaptureModule — Oracle Cloud Sync
- [ ] `GET /captures/pending` polling (every 2 min, configurable)
- [ ] Download and write markdown captures to iCloud Obsidian vault
- [ ] `POST /captures/ack` — acknowledge synced files
- [ ] Menu-bar indicator: last sync timestamp + pending count
- [ ] macOS Keychain storage for API key
- [ ] Configurable vault path + poll interval

### Infrastructure
- [ ] Preferences panel for per-module configuration
- [ ] Keychain-backed secret storage for API credentials
- [ ] Per-module enable/disable toggle
- [ ] Notification support for sync events

---

## Feature Status

| Symbol | Meaning |
|--------|---------|
| [x] | Implemented |
| [ ] | Planned |
