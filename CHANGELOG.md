# CommandCenter — Changelog

---

## Unreleased — WebCaptureModule

### Planned
- **WebCaptureModule** — polls Oracle Cloud server every 2 min
  - `GET /captures/vaults` → discover vaults with pending captures
  - `GET /captures/pending?vault=<name>` → download per-vault
  - `POST /captures/ack { vault, ids }` → acknowledge after writing
- **Multi-vault support** — `~/.config/commandcenter/vaults.json` maps server vault names to local iCloud vault paths; unknown vaults fall back to default
- `vaults.example.json` ships as a starting-point config
- Menu-bar status indicator: last sync time + total pending count
- Keychain storage for Oracle server API key
- Configurable poll interval via environment

---

## 2026-04-11 — Initial Release

### Added
- NSPanel-based menu-bar strip (28px × 520px, expands to ~75% screen height)
- `CommandBarModule` protocol — ObservableObject-conforming module interface
- **RemindersModule** — EventKit calendar and reminders with incremental + full fetch
- **JiraModule** — issue search via Jira REST API (`POST /rest/api/3/search/jql`)
- **ClipboardToolsModule** — clipboard snippet management via NSPasteboard
- **HackerNewsModule** — top stories from `hacker-news.firebaseio.com/v0/`
- **TerminalModule** — terminal path detection and launch shortcuts
- **DXSoundsRemoteModule** — playback remote via AppleScript bridge
- **CareerModule** — LinkedIn/GitHub quick-access links
- **SpotlightModule** — system-wide Spotlight search integration
- **ShowcaseModule** — UI component showcase
- Design tokens system (colors, spacing, typography, border radii)
- Spring animations with staggered delays
- Generic `fetch<T: Decodable>()` + `fetchJSON()` URLSession helpers (10s timeout)
- `ClickablePanel` NSPanel subclass for key window focus on button interaction
- `LSUIElement = true` — runs without Dock icon
- Login item support via `ServiceManagement`
- `install.sh` — automated login item installer
