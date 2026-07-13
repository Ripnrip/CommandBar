import SwiftUI
import AppKit
import Combine
import Foundation
import OSLog
import ServiceManagement
import AVFoundation
import EventKit


// ============================================================
// 🎨 DESIGN TOKENS — Colors, spacing, typography, radii
// The style guide CommandBar lives by. Change here, change everywhere.
// Basically the Constitution but for pixels. 📜
// ============================================================

/// Design tokens for consistent styling across CommandBar 🖌️
enum DesignTokens {
    // MARK: - Dimensions

    /// Strip panel height — thin and elegant like a supermodel's eyebrow 📏
    static let stripHeight: CGFloat = 28

    /// Strip panel width — wide enough to be useful, narrow enough to be classy 📐
    static let stripWidth: CGFloat = 800

    /// Expanded panel width — room to breathe 🌬️
    static let expandedWidth: CGFloat = 1200
    
    /// Command center width ratio — takes up 30% of screen width 🎛️
    static let commandCenterWidthRatio: CGFloat = 0.30

    /// Expanded panel max height ratio — don't hog the screen, leave room for cat GIFs 🐱
    static let expandedMaxHeightRatio: CGFloat = 0.75
    
    /// Command center height ratio — nearly full height for large panel mode 🏗️
    static let commandCenterHeightRatio: CGFloat = 0.85

    /// Strip corner radius — rounded like a friendly conversation 🫧
    static let stripCornerRadius: CGFloat = 7

    /// Expanded panel corner radius — slightly rounder because expanded = fancier ✨
    static let expandedCornerRadius: CGFloat = 12

    /// Right padding from screen edge — a polite margin, not socially awkward close 👋
    static let rightPadding: CGFloat = 8

    /// Gap between strip and expanded panel — personal space matters 🧘
    static let stripToExpandedGap: CGFloat = 6

    // MARK: - Typography

    /// Icon size in the strip — not too big, not too small, Goldilocks approved 🐻
    static let stripIconSize: CGFloat = 12

    /// Label font size in the strip — readable but discreet 🔍
    static let stripLabelSize: CGFloat = 11

    /// Section header font size in expanded panel — assertive but not shouting 📢
    static let sectionHeaderSize: CGFloat = 13

    // MARK: - Colors

    /// Divider dot color — barely there, like a whisper between modules 🤫
    static let dividerColor = Color.secondary.opacity(0.3)

    /// Divider dot size — tiny but mighty 💎
    static let dividerSize: CGFloat = 3

    /// Border stroke opacity — ghost-level visibility 👻
    static let borderOpacity: Double = 0.1

    /// Border stroke width — hairline thin, like a spider's thread 🕷️
    static let borderWidth: CGFloat = 0.5
}



// ============================================================
// 🎬 ANIMATION CONSTANTS — Centralized timing & spring configs
// One place to tweak all the juicy animations.
// Because hardcoded magic numbers are a crime against readability. 🚨
// ============================================================

/// Centralized animation constants — the choreographer of CommandBar's dance moves 💃
enum AnimationConstants {
    /// Spring animation for the expanded panel reveal — bouncy but not Tigger-level 🐯
    static let panelSpring = Animation.spring(response: 0.35, dampingFraction: 0.82)

    /// Stagger delay between each module section appearing — the domino effect ⏱️
    static let staggerDelay: Double = 0.05

    /// NSAnimationContext duration for panel frame changes — smooth like butter 🧈
    static let panelFrameDuration: Double = 0.3

    /// Icon hover scale — subtle flex, not a full workout 💪
    static let iconHoverScale: CGFloat = 1.15

    /// Icon press scale — a little squeeze to show you mean business 🤏
    static let iconPressScale: CGFloat = 0.9

    /// Rotation animation for the showcase sparkle icon — spin cycle ✨
    static let rotationDuration: Double = 3.0
}



// ============================================================
// 🌫️ VIBRANCY BACKGROUND — Frosted glass effects for panels
// Because plain backgrounds are so 2019. We live in the blur era. 😎
// ============================================================

/// A vibrancy background modifier for that sweet frosted glass look 🧊
struct VibrancyBackground: ViewModifier {
    let cornerRadius: CGFloat
    let material: Material

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(DesignTokens.borderOpacity),
                            lineWidth: DesignTokens.borderWidth)
            )
    }
}

extension View {
    /// Apply the CommandBar vibrancy background — instant glass morphism upgrade ✨
    func commandBarBackground(
        cornerRadius: CGFloat = DesignTokens.stripCornerRadius,
        material: Material = .ultraThinMaterial
    ) -> some View {
        modifier(VibrancyBackground(cornerRadius: cornerRadius, material: material))
    }
}

// MARK: - Shimmer Effect

/// Shimmer modifier for loading states ✨
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 100)
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

extension View {
    /// Add shimmer effect to indicate loading ✨
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Bounce Animation

/// Bounce effect for interactive elements 🎾
struct BounceModifier: ViewModifier {
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(trigger ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: trigger)
    }
}

extension View {
    /// Add bounce animation on trigger 🎾
    func bounce(trigger: Bool) -> some View {
        modifier(BounceModifier(trigger: trigger))
    }
}

// MARK: - Interactive Button Style

/// Custom button style with hover and press animations 🎯
struct InteractiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Liquid Glass Effect

/// Liquid Glass effect wrapper for CommandBar panels 🌊
/// Uses NSGlassEffectView for authentic macOS Dynamic Island vibes
@available(macOS 26.0, *)
struct LiquidGlassBackground: NSViewRepresentable {
    let cornerRadius: CGFloat
    var tintColor: NSColor? = nil
    var isInteractive: Bool = false
    
    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        glassView.cornerRadius = cornerRadius
        glassView.tintColor = tintColor
        return glassView
    }
    
    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.tintColor = tintColor
    }
}

/// Liquid Glass container for multiple glass elements that can merge 🌊
/// Creates the Dynamic Island morphing effect when elements move close together
@available(macOS 26.0, *)
struct LiquidGlassContainer: NSViewRepresentable {
    let spacing: CGFloat
    
    func makeNSView(context: Context) -> NSGlassEffectContainerView {
        let containerView = NSGlassEffectContainerView()
        containerView.spacing = spacing
        return containerView
    }
    
    func updateNSView(_ nsView: NSGlassEffectContainerView, context: Context) {
        nsView.spacing = spacing
    }
}

extension View {
    /// Apply Liquid Glass background effect — Dynamic Island style 🏝️
    @available(macOS 26.0, *)
    func liquidGlassBackground(
        cornerRadius: CGFloat = DesignTokens.stripCornerRadius,
        tint: NSColor? = nil,
        interactive: Bool = false
    ) -> some View {
        self.background(
            LiquidGlassBackground(
                cornerRadius: cornerRadius,
                tintColor: tint,
                isInteractive: interactive
            )
        )
    }
}



// ============================================================
// 🍎 APPLESCRIPT BRIDGE — Talk to macOS apps like a diplomat
// Detects active projects, opens terminals, reads app state.
// The embassy between CommandBar and the rest of macOS. 🏛️
// ============================================================

/// Bridges CommandBar to macOS apps via AppleScript — the interpreter 🗣️
@MainActor
final class AppleScriptBridge {
    private static let logger = Logger(subsystem: "com.commandbar.app", category: "AppleScript")

    /// Detect the current project path from the frontmost app 🔍
    /// Checks Xcode first (workspace path), then Finder (window path)
    static func detectProjectPath() -> String? {
        // Try Xcode first — the developer's natural habitat 🏕️
        if let xcodePath = getXcodeProjectPath() {
            return xcodePath
        }

        // Fall back to Finder — the civilian's file browser 📁
        if let finderPath = getFinderPath() {
            return finderPath
        }

        // Last resort: home directory — everyone's got one 🏠
        return FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// Get the active Xcode workspace/project directory 🛠️
    private static func getXcodeProjectPath() -> String? {
        let script = """
        tell application "System Events"
            if not (exists process "Xcode") then return ""
        end tell
        tell application "Xcode"
            if (count of workspace documents) > 0 then
                set wsPath to path of workspace document 1
                -- Get the directory containing the workspace/project
                set tid to AppleScript's text item delimiters
                set AppleScript's text item delimiters to "/"
                set pathParts to text items of wsPath
                -- Remove the last component (.xcworkspace or .xcodeproj file)
                set AppleScript's text item delimiters to "/"
                set parentPath to (items 1 through -2 of pathParts) as text
                set AppleScript's text item delimiters to tid
                return parentPath
            end if
        end tell
        return ""
        """

        return runAppleScript(script)
    }

    /// Get the current Finder window's path 📂
    private static func getFinderPath() -> String? {
        let script = """
        tell application "Finder"
            if (count of Finder windows) > 0 then
                set currentFolder to (folder of front window) as alias
                return POSIX path of currentFolder
            end if
        end tell
        return ""
        """

        return runAppleScript(script)
    }

    /// Open iTerm2 at the given path — the developer's preferred portal 🚀
    /// Falls back to Terminal.app if iTerm2 isn't installed (the horror!)
    static func openTerminal(at path: String) {
        // Try iTerm2 first — the fancy terminal for fancy developers 💅
        if appExists("iTerm") || appExists("iTerm2") {
            let script = """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                end if
                tell current session of current window
                    write text "cd \(escapePath(path))"
                end tell
            end tell
            """
            _ = runAppleScript(script)
        } else {
            // Fallback to Terminal.app — still gets the job done 🤷
            let script = """
            tell application "Terminal"
                activate
                do script "cd \(escapePath(path))"
            end tell
            """
            _ = runAppleScript(script)
        }
    }

    /// Check if an app exists on the system 🔎
    private static func appExists(_ appName: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil ||
        FileManager.default.fileExists(atPath: "/Applications/iTerm.app")
    }

    /// Run an AppleScript and return the result — the actual execution engine ⚙️
    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)

        if let error = error {
            logger.error("AppleScript error: \(error)")
            return nil
        }

        let value = result?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == true) ? nil : value
    }

    /// Escape a file path for safe AppleScript embedding — no injection here! 🛡️
    private static func escapePath(_ path: String) -> String {
        return "\"" + path.replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}



// ============================================================
// 🚀 LAUNCH AT LOGIN — Auto-start CommandBar on boot
// Because manually launching your toolbar is so 2005.
// Set it and forget it, like a crockpot. 🍲
// ============================================================

/// Manages auto-launch on login via SMAppService 🔑
enum LaunchAtLogin {
    private static let logger = Logger(subsystem: "com.commandbar.app", category: "LaunchAtLogin")

    /// Register the app to launch at login — welcome to the startup club 🎉
    static func enable() {
        do {
            try SMAppService.mainApp.register()
            logger.info("Auto-launch enabled — CommandBar will start on login ✅")
        } catch {
            logger.error("Failed to enable auto-launch: \(error.localizedDescription)")
        }
    }

    /// Unregister from login items — taking a sabbatical 🏖️
    static func disable() {
        do {
            try SMAppService.mainApp.unregister()
            logger.info("Auto-launch disabled — CommandBar will not start on login ❌")
        } catch {
            logger.error("Failed to disable auto-launch: \(error.localizedDescription)")
        }
    }

    /// Check current registration status — are we in the club? 🪪
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}



// ============================================================
// 🌐 NETWORK SERVICE — HTTP client for CommandBar modules
// Handles API calls with timeouts, error handling, and retry logic.
// Because URLSession alone is like driving without GPS. 🗺️
// ============================================================

/// Shared network service — the postal worker of CommandBar 📮
actor NetworkService {
    static let shared = NetworkService()

    private let logger = Logger(subsystem: "com.commandbar.app", category: "Network")

    /// Fetch JSON from a URL and decode it — the bread and butter of API work 🍞
    func fetch<T: Decodable>(_ type: T.Type, from urlString: String, timeout: TimeInterval = 10) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(type, from: data)
    }

    /// Fetch raw JSON dictionary — for when the response shape is unpredictable 🎲
    func fetchJSON(from urlString: String, timeout: TimeInterval = 10) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.decodingFailed
        }

        return json
    }

    /// Quick connectivity check — like pinging but classier 🏓
    func isReachable(url urlString: String, timeout: TimeInterval = 3) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

/// Network errors — when the internet says "nah" 🙅
enum NetworkError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "HTTP error: \(code)"
        case .decodingFailed: return "Failed to decode response"
        }
    }
}



// ============================================================
// 🧩 MODULE PROTOCOL — The contract every CommandBar module signs
// Implement this and you get a spot on the strip + expanded panel.
// It's like a VIP pass, but for code. 🎫
// ============================================================

/// Every CommandBar module must conform to this protocol.
/// Strip info (id, sfSymbol, stripLabel, accentColor) and a refresh method.
/// Expanded views are handled via separate View structs. 📋
@MainActor
protocol CommandBarModule: ObservableObject, Identifiable {
    /// Unique identifier for the module 🎤
    var id: String { get }

    /// SF Symbol name for the strip icon 😎
    var sfSymbol: String { get }

    /// Short label shown next to the icon on the strip 🐦
    var stripLabel: String { get }

    /// Accent color for the module 🎨
    var accentColor: Color { get }

    /// Refresh the module's data 🔄
    func refresh() async
}



// ============================================================
// 🖱️ CLICKABLE PANEL — NSPanel subclass that actually accepts clicks
// The default .nonactivatingPanel won't become key, so SwiftUI buttons
// just sit there looking pretty but doing nothing. Like a decorative sword.
// This subclass fixes that by saying "yes I CAN become key, thank you." 🗡️→⚔️
// ============================================================

/// An NSPanel that can become key window — required for SwiftUI button clicks 🎯
/// Without this, .nonactivatingPanel style panels ignore all button interactions.
/// Apple's idea of "non-activating" apparently means "non-functioning" too. 🍎🤦
///
/// Note: Both the strip AND expanded panel use this class. makeKey() is essential —
/// without it, .nonactivatingPanel won't deliver events to SwiftUI buttons at all.
/// The focus-stealing issue is solved by setting hidesOnDeactivate = false on the
/// expanded panel, so it doesn't care when the strip steals key status. 🤝
class ClickablePanel: NSPanel {

    /// Yes, we can become key — this is the magic line that makes buttons work 🔑
    override var canBecomeKey: Bool { true }

    /// Send mouse events to SwiftUI content — makeKey() is required for button delivery 🖱️
    /// canBecomeKey alone isn't enough for .nonactivatingPanel — we must actively claim
    /// key status on mouse down so SwiftUI buttons actually fire their actions. 🔫
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            makeKey()
        }
        super.sendEvent(event)
    }
}



// ============================================================
// 📊 STRIP PANEL — The thin floating toolbar below the menu bar
// Always visible. Always judging. Always there for you. 🫡
// Now on EVERY monitor — because one strip is never enough. 🖥️🖥️🖥️
// Ported from DX Sounds' StatusBarPanel with CommandBar enhancements.
// ============================================================

/// Manages floating strip panels — one per connected monitor 🎛️
/// Like a hydra: cut one head off, two more appear on your displays. 🐍
class StripPanel {
    private var panels: [NSPanel] = []
    private var hostingViews: [NSHostingView<AnyView>] = []
    private var screenObserver: NSObjectProtocol?

    init() {
        // Watch for monitor changes — plugging in a second screen shouldn't require a restart 🔌
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildPanels()
        }
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// The last content shown — cached so we can rebuild panels on screen changes 📦
    private var lastContent: AnyView?

    /// Show the strip panel on ALL connected monitors 🎬
    /// Creates one panel per screen on first call, updates content on subsequent calls.
    func show<Content: View>(content: Content) {
        let wrapped = AnyView(content)
        lastContent = wrapped

        guard panels.isEmpty else {
            // Panels already exist — just update content on all of them 🔄
            for hostingView in hostingViews {
                hostingView.rootView = wrapped
            }
            return
        }

        buildPanels(with: wrapped)
    }

    /// Update content without recreating panels — efficient refresh across all screens 🔄
    func update<Content: View>(content: Content) {
        let wrapped = AnyView(content)
        lastContent = wrapped
        for hostingView in hostingViews {
            hostingView.rootView = wrapped
        }
    }

    /// Hide and destroy ALL panels — goodnight sweet princes 🌙
    func hide() {
        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
        hostingViews.removeAll()
        lastContent = nil
    }

    /// Whether any panel is currently showing — are we on stage anywhere? 🎭
    var isVisible: Bool { !panels.isEmpty }

    /// Returns the frame of whichever strip contains the given point 📏
    /// Used to figure out which monitor's strip was clicked — detective work 🔍
    func frame(at mouseLocation: NSPoint) -> NSRect? {
        for panel in panels {
            if panel.frame.contains(mouseLocation) {
                return panel.frame
            }
        }
        // Mouse isn't directly on a strip — find the closest screen and return that strip's frame
        // This handles cases where the click is on the expanded panel below a strip 🎯
        return closestStripFrame(to: mouseLocation)
    }

    /// All strip panel frames — the full lineup 📐
    /// Used by ExpandedPanelController to know which rects to ignore for click-outside 🎯
    var allFrames: [NSRect] {
        panels.map { $0.frame }
    }

    // MARK: - Private

    /// Build one panel per connected screen — the assembly line 🏭
    private func buildPanels(with content: AnyView) {
        for screen in NSScreen.screens {
            let panelHeight = DesignTokens.stripHeight
            let panelWidth = DesignTokens.stripWidth
            let rightPadding = DesignTokens.rightPadding

            // visibleFrame.maxY = bottom edge of menu bar in Cocoa coords
            // Place strip just below that on each screen 📏
            let panelX = screen.visibleFrame.maxX - panelWidth - rightPadding
            let panelY = screen.visibleFrame.maxY - panelHeight - 2

            let frame = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

            // Create the NSPanel with specific behavior flags 🏗️
            let p = ClickablePanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            // Panel configuration — invisible borders, always on top, follows spaces 👻
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = .statusBar                    // Lives at menu bar level — VIP seating 🎟️
            p.collectionBehavior = [
                .canJoinAllSpaces,                  // Follows you across Spaces like a loyal dog 🐕
                .stationary,                        // Doesn't move when you switch Spaces
                .fullScreenAuxiliary                // Visible even in fullscreen apps
            ]
            p.isMovableByWindowBackground = true    // Draggable — reposition at will! 🎯
            p.hidesOnDeactivate = false             // Always visible, even when app isn't focused
            p.acceptsMouseMovedEvents = true        // Track mouse for hover effects 🖱️

            // Set up the SwiftUI hosting view
            let hosting = NSHostingView(rootView: content)
            hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
            p.contentView = hosting

            // Show it! 🎉
            p.orderFrontRegardless()

            panels.append(p)
            hostingViews.append(hosting)
        }
    }

    /// Rebuild panels when monitors change — the metamorphosis 🦋
    /// Triggered by didChangeScreenParametersNotification (plug/unplug monitors)
    private func rebuildPanels() {
        guard let content = lastContent else { return }

        // Tear down existing panels 🧹
        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
        hostingViews.removeAll()

        // Rebuild for current screen configuration 🏗️
        buildPanels(with: content)
    }

    /// Find the strip frame on the screen closest to the given point 🎯
    /// Fallback for when the mouse isn't directly over a strip panel
    private func closestStripFrame(to point: NSPoint) -> NSRect? {
        guard !panels.isEmpty else { return nil }

        // Find which screen contains the point, then return that screen's strip
        for (index, screen) in NSScreen.screens.enumerated() {
            if screen.frame.contains(point), index < panels.count {
                return panels[index].frame
            }
        }

        // Last resort: return first panel's frame — there's always a primary 🏠
        return panels.first?.frame
    }
}



// ============================================================
// 📦 EXPANDED PANEL CONTROLLER — The dropdown content panel
// Drops down from the strip with spring animation.
// Now screen-aware — drops from whichever strip you click! 🎭🖥️
// ============================================================

/// Manages the expanded dropdown panel positioned below the strip 📋
/// Multi-monitor savvy — anchors to the correct screen's strip panel.
class ExpandedPanelController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var clickMonitor: Any?
    private var localClickMonitor: Any?

    /// Show the expanded panel anchored below the strip on the correct screen 🎬
    func show<Content: View>(content: Content, below stripFrame: NSRect, isCommandCenter: Bool = false) {
        // If already visible, just update content and reposition if needed
        if let existing = panel, existing.isVisible {
            hostingView?.rootView = AnyView(content)
            repositionIfNeeded(below: stripFrame, isCommandCenter: isCommandCenter)
            return
        }

        // Find the screen that contains this strip — CSI: Monitor Edition 🔍
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(stripFrame.origin) })
                ?? NSScreen.screens.first else { return }

        let panelWidth: CGFloat
        let maxHeight: CGFloat
        
        if isCommandCenter {
            // Command center mode — 30% of screen width, 85% height 🎛️
            panelWidth = screen.visibleFrame.width * DesignTokens.commandCenterWidthRatio
            maxHeight = screen.visibleFrame.height * DesignTokens.commandCenterHeightRatio
        } else {
            // Normal expanded mode
            panelWidth = DesignTokens.expandedWidth
            maxHeight = screen.visibleFrame.height * DesignTokens.expandedMaxHeightRatio
        }
        
        let rightPadding = DesignTokens.rightPadding

        // Create hosting view to measure content size 📏
        // Constrain width first so height is calculated for our actual panel width,
        // not some imaginary infinite canvas. SwiftUI loves to dream big. 💭
        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: 0)
        let fittingSize = hosting.fittingSize

        // Cap height at max 
        let panelHeight = min(fittingSize.height + 20, maxHeight)

        // Position: right-aligned on the CORRECT screen, anchored below its strip 📐
        let panelX = screen.visibleFrame.maxX - panelWidth - rightPadding
        let panelY = stripFrame.minY - panelHeight - DesignTokens.stripToExpandedGap

        // Start with zero height for animation — the reveal begins at nothing 🎪
        let startFrame = NSRect(x: panelX, y: stripFrame.minY - DesignTokens.stripToExpandedGap,
                                width: panelWidth, height: 0)
        let endFrame = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

        let p = ClickablePanel(
            contentRect: startFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating                     // Floats above normal windows but below strip 🎈
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false             // We handle dismiss ourselves via click monitors 🚪

        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        p.contentView = hosting

        p.orderFrontRegardless()

        // Animate the panel frame expanding downward — the grand entrance 🎬
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = AnimationConstants.panelFrameDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            p.animator().setFrame(endFrame, display: true)
        })

        self.panel = p
        self.hostingView = hosting

        // Monitor for clicks outside the panel — click-to-dismiss 🖱️
        setupClickOutsideMonitor()
    }

    /// Hide the panel with collapse animation — the graceful exit 🌙
    func hide() {
        guard let p = panel else { return }

        // Remove click monitors (both global + local) 🧹
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }

        // Animate collapse — shrink back up to the strip 📏
        let collapsedFrame = NSRect(
            x: p.frame.origin.x,
            y: p.frame.maxY,
            width: p.frame.width,
            height: 0
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = AnimationConstants.panelFrameDuration * 0.7
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            p.animator().setFrame(collapsedFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
            self?.hostingView = nil
        })
    }

    /// Whether the panel is visible — are we showing our hand? 🃏
    var isVisible: Bool { panel?.isVisible ?? false }

    /// Update the content without recreating the panel 🔄
    func updateContent<Content: View>(_ content: Content) {
        hostingView?.rootView = AnyView(content)
    }

    // MARK: - Click Outside Monitor

    /// All strip panel frames — so we can ignore clicks on ANY strip across ALL monitors 🎯
    /// One strip to rule them all? Nah, we need to know about ALL of them. 💍
    var stripFrames: [NSRect] = []

    /// Set up click monitors (global + local) to dismiss when clicking outside 🖱️
    /// But NOT when clicking ANY strip — those are module taps, not dismissals! 🤝
    private func setupClickOutsideMonitor() {
        // Global monitor — catches clicks in other apps / desktop 🌍
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleClickOutside(mouseLocation: NSEvent.mouseLocation)
        }

        // Local monitor — catches clicks within CommandBar's own windows 🏠
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleClickOutside(mouseLocation: NSEvent.mouseLocation)
            return event  // Always pass the event through — we're observers, not blockers 🔍
        }
    }

    /// Shared click-outside handler — checks against ALL strip frames across monitors 🎯
    /// Now multi-monitor aware — won't dismiss when you click a strip on any screen! 🖥️🖥️
    private func handleClickOutside(mouseLocation: NSPoint) {
        guard let panel = self.panel else { return }

        // Ignore clicks on the expanded panel itself (obviously)
        if panel.frame.contains(mouseLocation) { return }

        // Ignore clicks on ANY strip panel — those are button taps, not dismiss requests! 🚫
        // Checks all monitors' strip frames — because clicking monitor 2's strip
        // while monitor 1's expanded panel is open shouldn't dismiss, it should MOVE. 🏃
        for frame in stripFrames {
            if frame.contains(mouseLocation) { return }
        }

        // Genuinely outside both panels — dismiss 👋
        NSLog("[Monitor] click-outside dismiss at (%.0f, %.0f)", mouseLocation.x, mouseLocation.y)
        NotificationCenter.default.post(name: .commandBarClickedOutside, object: nil)
        self.hide()
    }

    // MARK: - Repositioning

    /// Reposition the expanded panel if the user clicked a strip on a different monitor 🔀
    /// The panel slides over to the new screen — like a nomadic dropdown. 🏕️
    /// Also handles width changes when toggling between compact and command center modes! 🎛️
    private func repositionIfNeeded(below stripFrame: NSRect, isCommandCenter: Bool = false) {
        guard let p = panel, let hosting = hostingView else { return }

        // Find the screen for this strip
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(stripFrame.origin) })
                ?? NSScreen.screens.first else { return }

        let panelWidth: CGFloat
        if isCommandCenter {
            panelWidth = screen.visibleFrame.width * DesignTokens.commandCenterWidthRatio
        } else {
            panelWidth = DesignTokens.expandedWidth
        }
        
        let rightPadding = DesignTokens.rightPadding
        
        // Update hosting view width to match new panel width — critical for mode switching! 🔧
        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: hosting.frame.height)
        let fittingSize = hosting.fittingSize
        let panelHeight = min(fittingSize.height + 20, screen.visibleFrame.height * 
                            (isCommandCenter ? DesignTokens.commandCenterHeightRatio : DesignTokens.expandedMaxHeightRatio))

        let panelX = screen.visibleFrame.maxX - panelWidth - rightPadding
        let panelY = stripFrame.minY - panelHeight - DesignTokens.stripToExpandedGap

        let newFrame = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

        // Reposition if position OR width changed — handles mode switching and screen moves 🔀
        if abs(p.frame.origin.x - newFrame.origin.x) > 1 || 
           abs(p.frame.origin.y - newFrame.origin.y) > 1 ||
           abs(p.frame.width - newFrame.width) > 1 ||
           abs(p.frame.height - newFrame.height) > 1 {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = AnimationConstants.panelFrameDuration * 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                p.animator().setFrame(newFrame, display: true)
                hosting.animator().frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
            })
        }
    }
}

// Notification for click-outside events — the escape hatch 🚪
extension Notification.Name {
    static let commandBarClickedOutside = Notification.Name("commandBarClickedOutside")
}



// ============================================================
// 📂 TERMINAL MODULE — Detects your project, opens a terminal there
// Like a GPS for your command line. "You have arrived at ~/Dev/venmo" 🗺️
// ============================================================

/// Opens iTerm2 (or Terminal.app) at the active Xcode/Finder project root 🚀
@MainActor
final class TerminalModule: ObservableObject, CommandBarModule {
    let id = "terminal"
    let sfSymbol = "terminal.fill"
    let accentColor = Color.green

    /// Detected project path — where the magic happens 📍
    @Published var detectedPath: String?

    /// Human-friendly folder name for the strip 📛
    var stripLabel: String {
        if let path = detectedPath {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return "Terminal"
    }

    /// Refresh — re-detect the active project path 🔍
    func refresh() async {
        detectedPath = AppleScriptBridge.detectProjectPath()
    }
}

/// Expanded view for the Terminal module — project info and open button 🖥️
struct TerminalExpandedView: View {
    @ObservedObject var module: TerminalModule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("Terminal")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
                Button(action: { Task { await module.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            if let path = module.detectedPath {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    Text(path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button(action: { AppleScriptBridge.openTerminal(at: path) }) {
                    HStack {
                        Image(systemName: "terminal.fill")
                        Text("Open iTerm Here")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(module.accentColor.opacity(0.15))
                    .foregroundColor(module.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Image(systemName: "questionmark.folder.fill")
                        .foregroundColor(.orange)
                    Text("No project detected. Open Xcode or Finder.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // Quick paths — common directories for fast access 🏎️
            HStack(spacing: 6) {
                quickPathButton("~", path: FileManager.default.homeDirectoryForCurrentUser.path)
                quickPathButton("Dev", path: NSHomeDirectory() + "/Developer")
                quickPathButton("Desktop", path: NSHomeDirectory() + "/Desktop")
            }
        }
        .padding(12)
    }

    private func quickPathButton(_ label: String, path: String) -> some View {
        Button(action: { AppleScriptBridge.openTerminal(at: path) }) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}


// ============================================================
// ☁️ COSMOS MODULE — Minimal placeholder until real source returns
// Added because the original app references CosmosModule but the repo
// does not include its source file.
// ============================================================

@MainActor
final class CosmosModule: ObservableObject, CommandBarModule {
    let id = "cosmos"
    let sfSymbol = "cloud.fill"
    let accentColor = Color.cyan

    @Published var statusText = "Cosmos module placeholder"

    var stripLabel: String { "Cosmos" }

    func refresh() async {
        statusText = "Cosmos module placeholder"
    }
}

struct CosmosExpandedView: View {
    @ObservedObject var module: CosmosModule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("Cosmos")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
                Button(action: { Task { await module.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            Text(module.statusText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("The original Cosmos source file is not present in this repo, so this section is a compile-safe placeholder.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(12)
    }
}

@MainActor
final class VPNCleanupModule: ObservableObject, CommandBarModule {
    let id = "vpn-cleanup"
    let sfSymbol = "network.badge.shield.half.filled"
    let accentColor = Color.red

    @Published var statusText = "Ready"
    @Published var isRunning = false

    var stripLabel: String { "VPN Fix" }

    func refresh() async {}

    func runCleanup() {
        guard !isRunning else { return }
        isRunning = true
        statusText = "Running cleanup..."

        let scriptPath = NSHomeDirectory() + "/Documents/Developer/CommandCenter/scripts/vpn-zombie-cleanup.sh"
        let escapedPath = scriptPath.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        do shell script "zsh \\"\(escapedPath)\\"" with administrator privileges
        """
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: source)
        let result = appleScript?.executeAndReturnError(&error)

        isRunning = false
        if let error {
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "Cleanup failed"
            statusText = message
            return
        }
        statusText = result?.stringValue?.isEmpty == false ? result!.stringValue! : "Cleanup complete"
    }
}

struct VPNCleanupExpandedView: View {
    @ObservedObject var module: VPNCleanupModule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("VPN Cleanup")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
            }

            Divider()

            Text("Kills stale Nord/Tailscale sessions, resets primary interface, flushes DNS, and prints route + DNS checks.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(module.statusText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)

            Button(action: { module.runCleanup() }) {
                HStack {
                    Image(systemName: module.isRunning ? "hourglass" : "wrench.and.screwdriver.fill")
                    Text(module.isRunning ? "Running..." : "Run VPN Zombie Cleanup")
                }
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(module.accentColor.opacity(0.15))
                .foregroundColor(module.accentColor)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(module.isRunning)
        }
        .padding(12)
    }
}


// ============================================================
// 🔊 DX SOUNDS REMOTE MODULE — Control DX Sounds from CommandBar
// Now with cover art, theme discovery, session stats, and sound preview!
// Basically the full DX Sounds app crammed into a dropdown panel. 📺🎵
// ============================================================

// MARK: - Session Stats

/// Session stats from /tmp/dx-sounds-state.json — the live scoreboard 🏆
struct DXSessionState {
    var streak: Int = 0
    var totalAchievements: Int = 0
    var editsInWindow: Int = 0
    var firstBlood: Bool = false

    /// Streak tier name — Quake-style ranking 💀
    var streakTier: String {
        switch streak {
        case 0..<5:   return ""
        case 5..<8:   return "Rampage"
        case 8..<12:  return "Dominating"
        case 12..<15: return "Unstoppable"
        case 15..<20: return "Godlike"
        default:      return "HOLY SHIT"
        }
    }

    /// Streak tier color — hotter = redder 🌡️
    var streakColor: Color {
        switch streak {
        case 0..<5:   return .secondary
        case 5..<8:   return .yellow
        case 8..<12:  return .orange
        case 12..<15: return .red
        case 15..<20: return .purple
        default:      return .pink
        }
    }

    /// SF Symbol for streak level — escalating intensity 📈
    var streakIcon: String {
        switch streak {
        case 0..<5:   return "flame"
        case 5..<8:   return "flame.fill"
        case 8..<12:  return "bolt.fill"
        case 12..<15: return "bolt.trianglebadge.exclamationmark.fill"
        case 15..<20: return "star.fill"
        default:      return "sparkles"
        }
    }
}

// MARK: - Theme Info

/// Discovered theme metadata — cover art, sounds, events 🎨
struct DXThemeInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let variants: [String]?
    let defaultVariant: String?
    let eventNames: [String]
    let soundCount: Int
    let coverImagePath: String?
    let themeDir: URL
}

// MARK: - Config

/// DXConfig shared with DX Sounds — same struct, same file 🤝
struct DXConfig: Codable {
    var theme: String
    var variant: String
    var mode: String
    var volume: Double
    var cooldown: Int
    var install_path: String?
    var enabled: Bool

    static let fallback = DXConfig(
        theme: "quake", variant: "male", mode: "arena",
        volume: 1.0, cooldown: 4, install_path: nil, enabled: true
    )
}

// MARK: - Module

/// Remote control for DX Sounds — now with full theme discovery and sound preview 🎛️
/// Like the original DX Sounds app, but living inside CommandBar. Cozy. 🏠
@MainActor
final class DXSoundsRemoteModule: ObservableObject, CommandBarModule {
    let id = "dxsounds"
    let sfSymbol = "speaker.wave.2.fill"
    let accentColor = Color.orange

    private let logger = Logger(subsystem: "com.commandbar.app", category: "DXSounds")
    private let configPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/dx-sounds/config.json")
    private let statePath = URL(fileURLWithPath: "/tmp/dx-sounds-state.json")

    @Published var config: DXConfig = .fallback
    @Published var session: DXSessionState = DXSessionState()
    @Published var themes: [DXThemeInfo] = []
    @Published var isInstalled = false
    @Published var nowPlaying: String?

    private var audioPlayer: AVAudioPlayer?

    var stripLabel: String {
        guard isInstalled else { return "N/A" }
        return config.enabled ? themeEmoji : "🔇"
    }

    var themeEmoji: String {
        switch config.theme {
        case "quake":          return "💀"
        case "mario":          return "🍄"
        case "bollywood":      return "🎬"
        case "movie-villains": return "🦹"
        case "game-show":      return "🎰"
        case "simpsons":       return "🍩"
        case "the-office":     return "📎"
        default:               return "🎧"
        }
    }

    /// Where themes live — auto-detected or from config 📂
    private var installPath: URL {
        if let ip = config.install_path, !ip.isEmpty {
            return URL(fileURLWithPath: ip)
        }
        return detectInstallPath()
    }

    private var themesDir: URL { installPath.appendingPathComponent("themes") }

    /// Currently active theme info 🎯
    var currentThemeInfo: DXThemeInfo? {
        themes.first(where: { $0.id == config.theme })
    }

    /// Whether current theme has multiple voice variants 🎙️
    var hasVariants: Bool {
        guard let info = currentThemeInfo else { return false }
        return info.variants != nil && (info.variants?.count ?? 0) > 1
    }

    /// Available variants for current theme
    var currentVariants: [String] {
        currentThemeInfo?.variants ?? []
    }

    /// Events mapped in current theme
    var currentEvents: [String] {
        currentThemeInfo?.eventNames ?? []
    }

    func refresh() async {
        loadConfig()
        loadSessionState()
        discoverThemes()
    }

    // MARK: - Actions

    func toggleEnabled() {
        config.enabled.toggle()
        saveConfig()
    }

    func setTheme(_ themeID: String) {
        config.theme = themeID
        if let info = themes.first(where: { $0.id == themeID }),
           let dv = info.defaultVariant {
            config.variant = dv
        }
        saveConfig()
    }

    func setMode(_ mode: String) {
        guard ["arena", "casual", "zen"].contains(mode) else { return }
        config.mode = mode
        saveConfig()
    }

    func setVariant(_ variant: String) {
        config.variant = variant
        saveConfig()
    }

    func setVolume(_ volume: Double) {
        config.volume = max(0, min(1, volume))
        saveConfig()
    }

    /// Play a test sound for a specific event 🎸
    func playTestSound(event: String = "test.pass") {
        let themeDir = themesDir.appendingPathComponent(config.theme)
        playSound(from: themeDir, event: event, key: event)
    }

    /// Preview a sound from any theme (not just active) 🎧
    func previewSound(themeID: String, event: String) {
        guard let info = themes.first(where: { $0.id == themeID }) else { return }
        playSound(from: info.themeDir, event: event, key: "\(themeID):\(event)")
    }

    /// Stop playback 🛑
    func stopSound() {
        audioPlayer?.stop()
        nowPlaying = nil
    }

    /// Open theme folder in Finder 📂
    func openThemeFolder() {
        NSWorkspace.shared.open(themesDir.appendingPathComponent(config.theme))
    }

    /// Open config folder in Finder ⚙️
    func openConfigFolder() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/dx-sounds")
        NSWorkspace.shared.open(configDir)
    }

    /// Open install folder in Finder 🏠
    func openInstallFolder() {
        NSWorkspace.shared.open(installPath)
    }

    // MARK: - Private

    private func loadConfig() {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            isInstalled = false
            return
        }
        isInstalled = true
        do {
            let data = try Data(contentsOf: configPath)
            config = try JSONDecoder().decode(DXConfig.self, from: data)
        } catch {
            logger.error("Failed to read DX Sounds config: \(error.localizedDescription)")
        }
    }

    private func saveConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configPath, options: .atomic)
        } catch {
            logger.error("Failed to save DX Sounds config: \(error.localizedDescription)")
        }
    }

    private func loadSessionState() {
        guard FileManager.default.fileExists(atPath: statePath.path) else {
            session = DXSessionState()
            return
        }
        do {
            let data = try Data(contentsOf: statePath)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            session.streak = json["streak"] as? Int ?? 0
            session.totalAchievements = json["total_achievements"] as? Int ?? 0
            session.editsInWindow = json["edits_in_window"] as? Int ?? 0
            session.firstBlood = json["first_blood"] as? Bool ?? false
        } catch {
            logger.error("Failed to read session state: \(error.localizedDescription)")
        }
    }

    /// Discover all themes from disk — cover art, events, sounds 🔍
    private func discoverThemes() {
        let fm = FileManager.default
        let dir = themesDir

        guard fm.fileExists(atPath: dir.path) else { return }

        do {
            let entries = try fm.contentsOfDirectory(atPath: dir.path)
            var found: [DXThemeInfo] = []

            for entry in entries.sorted() {
                if entry == "_template" || entry.hasPrefix(".") { continue }
                let themeJSON = dir.appendingPathComponent(entry).appendingPathComponent("theme.json")
                guard fm.fileExists(atPath: themeJSON.path) else { continue }

                if let info = parseTheme(id: entry, manifest: themeJSON,
                                          themeDir: dir.appendingPathComponent(entry)) {
                    found.append(info)
                }
            }
            themes = found
        } catch {
            logger.error("Failed to scan themes: \(error.localizedDescription)")
        }
    }

    /// Parse a single theme.json into DXThemeInfo 📋
    private func parseTheme(id: String, manifest: URL, themeDir: URL) -> DXThemeInfo? {
        do {
            let data = try Data(contentsOf: manifest)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            let name = json["name"] as? String ?? id.capitalized
            let desc = json["description"] as? String ?? ""
            let variants = json["variants"] as? [String]
            let defaultVariant = json["default_variant"] as? String

            var eventNames: [String] = []
            if let events = json["events"] as? [String: Any] {
                for (key, value) in events.sorted(by: { $0.key < $1.key }) {
                    if !(value is NSNull) { eventNames.append(key) }
                }
            }

            let soundsDir = themeDir.appendingPathComponent("sounds")
            var soundCount = 0
            if let enumerator = FileManager.default.enumerator(atPath: soundsDir.path) {
                while let file = enumerator.nextObject() as? String {
                    if file.hasSuffix(".mp3") { soundCount += 1 }
                }
            }

            let coverPath = themeDir.appendingPathComponent("cover.png").path
            let coverImagePath = FileManager.default.fileExists(atPath: coverPath) ? coverPath : nil

            return DXThemeInfo(id: id, name: name, description: desc,
                              variants: variants, defaultVariant: defaultVariant,
                              eventNames: eventNames, soundCount: soundCount,
                              coverImagePath: coverImagePath, themeDir: themeDir)
        } catch {
            return nil
        }
    }

    /// Play a sound from a theme directory 🎵
    private func playSound(from themeDir: URL, event: String, key: String) {
        let themeJSON = themeDir.appendingPathComponent("theme.json")
        guard FileManager.default.fileExists(atPath: themeJSON.path) else { return }

        do {
            let data = try Data(contentsOf: themeJSON)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let events = json["events"] as? [String: Any],
                  let eventDef = events[event],
                  !(eventDef is NSNull),
                  let eventDict = eventDef as? [String: Any] else { return }

            let variantKey: String
            if let variants = json["variants"] as? [String], !variants.isEmpty {
                variantKey = config.variant
            } else {
                variantKey = "_default"
            }

            guard let relPath = resolveSoundPath(eventDict: eventDict, variantKey: variantKey) else { return }
            let soundFile = themeDir.appendingPathComponent(relPath)
            guard FileManager.default.fileExists(atPath: soundFile.path) else { return }

            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: soundFile)
            audioPlayer?.volume = Float(config.volume)
            audioPlayer?.play()

            nowPlaying = key
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if nowPlaying == key { nowPlaying = nil }
            }
        } catch {
            logger.error("Sound playback failed: \(error.localizedDescription)")
        }
    }

    /// Resolve sound file path from event dict — handles string and array values 🎯
    private func resolveSoundPath(eventDict: [String: Any], variantKey: String) -> String? {
        if let val = eventDict[variantKey] {
            if let str = val as? String { return str }
            if let arr = val as? [String], let first = arr.first { return first }
        }
        if let fallback = eventDict["_default"] {
            if let str = fallback as? String { return str }
            if let arr = fallback as? [String], let first = arr.first { return first }
        }
        return nil
    }

    /// Auto-detect DX Sounds install path 🔍
    private func detectInstallPath() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Developer/paypal/dx-sounds"),
            home.appendingPathComponent("projects/dx-sounds"),
            home.appendingPathComponent(".local/share/dx-sounds"),
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("themes").path) {
                return candidate
            }
        }
        return home.appendingPathComponent("Developer/paypal/dx-sounds")
    }
}

// ============================================================
// 🎨 EXPANDED VIEW — Full DX Sounds panel with cover art & previews
// Ported from the standalone DX Sounds menu bar app.
// All the visuals, none of the separate process. 🎁
// ============================================================

struct DXSoundsExpandedView: View {
    @ObservedObject var module: DXSoundsRemoteModule
    @State private var showEvents = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header — gradient icon + status 🏷️
            headerSection

            Divider()

            if !module.isInstalled {
                notInstalledView
            } else {
                VStack(spacing: 10) {
                    sessionStatsCard
                    themeSection
                    modeSection
                    if module.hasVariants { variantSection }
                    volumeSection
                    soundPreviewSection
                    controlsRow
                    folderActions
                }
            }
        }
        .padding(12)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("DX Sounds")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .bold))
                HStack(spacing: 4) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 8)).foregroundColor(.purple)
                    Text(module.currentThemeInfo?.name ?? module.config.theme.capitalized)
                        .font(.system(size: 10)).foregroundColor(.secondary)
                    Text("·").foregroundColor(.secondary.opacity(0.5))
                    Image(systemName: modeIcon(module.config.mode))
                        .font(.system(size: 8))
                        .foregroundColor(modeColor(module.config.mode))
                    Text(module.config.mode.capitalized)
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }

            Spacer()

            ZStack {
                if module.config.enabled {
                    Circle().fill(.green.opacity(0.3)).frame(width: 14, height: 14)
                }
                Circle()
                    .fill(module.config.enabled ? .green : .red.opacity(0.6))
                    .frame(width: 8, height: 8)
            }

            Button(action: { Task { await module.refresh() } }) {
                Image(systemName: "arrow.clockwise").font(.system(size: 10)).foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Session Stats Card

    private var sessionStatsCard: some View {
        VStack(spacing: 0) {
            // Streak banner 🔥
            if module.session.streak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: module.session.streakIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(module.session.streakColor)

                    if !module.session.streakTier.isEmpty {
                        Text(module.session.streakTier.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(module.session.streakColor)
                    }

                    Spacer()

                    Text("\(module.session.streak) streak")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundColor(module.session.streakColor)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(module.session.streakColor.opacity(0.1)))
            }

            // Stats row — achievements, combos, first blood 🏆
            HStack(spacing: 0) {
                statBadge(icon: "trophy.fill", value: "\(module.session.totalAchievements)", label: "Achievements", color: .yellow)
                statBadge(icon: "pencil.and.outline", value: "\(module.session.editsInWindow)", label: "Edit Combo", color: .cyan)
                statBadge(icon: "drop.fill", value: module.session.firstBlood ? "Yes" : "—", label: "First Blood",
                         color: module.session.firstBlood ? .red : .secondary)
            }
            .padding(.top, module.session.streak > 0 ? 4 : 0)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.4)))
    }

    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(value).font(.system(size: 13, weight: .bold).monospacedDigit())
            Text(label).font(.system(size: 8)).foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Theme Picker (full-width cover art cards!)

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(icon: "paintpalette.fill", title: "Theme")

            // Horizontal scrolling carousel of theme cards — swipe through your soundtrack 🎠
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(module.themes) { theme in
                        themeCard(theme)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    /// Theme card — full cover art with overlay text, like a music app 🎨💿
    /// Because album art deserves to be SEEN, not thumbnailed into oblivion.
    private func themeCard(_ theme: DXThemeInfo) -> some View {
        let isSelected = theme.id == module.config.theme
        return Button(action: { module.setTheme(theme.id) }) {
            ZStack(alignment: .bottomLeading) {
                // Cover art — the hero image, full bleed 🖼️
                if let coverPath = theme.coverImagePath,
                   let nsImage = NSImage(contentsOfFile: coverPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 100)
                        .clipped()
                } else {
                    // Fallback gradient if no cover art 🎨
                    LinearGradient(
                        colors: themeGradient(for: theme.id),
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(width: 140, height: 100)
                    .overlay(
                        Text(themeEmoji(for: theme.id)).font(.system(size: 32))
                    )
                }

                // Gradient overlay for text readability — cinematic vibes 🎬
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                // Theme name + stats overlay 📝
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(theme.soundCount) sounds")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(8)

                // Selected checkmark badge ✅
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .shadow(color: .black.opacity(0.5), radius: 2)
                        }
                        Spacer()
                    }
                    .padding(6)
                }
            }
            .frame(width: 140, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode Cards

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "dial.medium.fill", title: "Mode")

            HStack(spacing: 4) {
                modeCard(id: "arena", label: "Arena", subtitle: "All sounds", icon: "flame.fill", color: .red)
                modeCard(id: "casual", label: "Casual", subtitle: "Highlights", icon: "scope", color: .orange)
                modeCard(id: "zen", label: "Zen", subtitle: "Big wins", icon: "leaf.fill", color: .green)
            }
        }
    }

    private func modeCard(id: String, label: String, subtitle: String, icon: String, color: Color) -> some View {
        let isSelected = module.config.mode == id
        return Button(action: { module.setMode(id) }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? color : .secondary)
                Text(label).font(.system(size: 10, weight: isSelected ? .bold : .medium))
                Text(subtitle).font(.system(size: 8)).foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Variant Picker

    private var variantSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "person.2.fill", title: "Variant")

            Picker("", selection: Binding(
                get: { module.config.variant },
                set: { module.setVariant($0) }
            )) {
                ForEach(module.currentVariants, id: \.self) { variant in
                    Text(variant.capitalized).tag(variant)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Volume

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                sectionHeader(icon: "speaker.wave.2.fill", title: "Volume")
                Spacer()
                Text("\(Int(module.config.volume * 100))%")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                Button(action: { module.setVolume(0) }) {
                    Image(systemName: "speaker.slash.fill").font(.system(size: 10)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Slider(value: Binding(
                    get: { module.config.volume },
                    set: { module.setVolume($0) }
                ), in: 0...1, step: 0.05)
                .controlSize(.small)

                Button(action: { module.setVolume(1.0) }) {
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 10)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Sound Preview

    private var soundPreviewSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showEvents.toggle() } }) {
                HStack {
                    sectionHeader(icon: "music.note.list", title: "Sound Preview")
                    Spacer()
                    Image(systemName: showEvents ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .medium)).foregroundColor(.secondary.opacity(0.7))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showEvents {
                VStack(spacing: 1) {
                    ForEach(module.currentEvents, id: \.self) { event in
                        eventRow(event)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func eventRow(_ event: String) -> some View {
        let isPlaying = module.nowPlaying == event
        return Button(action: { module.playTestSound(event: event) }) {
            HStack(spacing: 6) {
                Image(systemName: isPlaying ? "waveform" : eventIcon(for: event))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isPlaying ? .green : eventColor(for: event))
                    .frame(width: 14)

                Text(event)
                    .font(.system(size: 10, weight: isPlaying ? .bold : .regular).monospaced())
                    .foregroundColor(isPlaying ? .green : .primary)

                Spacer()

                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.circle")
                    .font(.system(size: 12))
                    .foregroundColor(isPlaying ? .green : .secondary.opacity(0.4))
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(isPlaying ? Color.green.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.3))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(spacing: 6) {
            Button(action: { module.toggleEnabled() }) {
                HStack(spacing: 4) {
                    Image(systemName: module.config.enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(module.config.enabled ? .green : .red)
                    Text(module.config.enabled ? "On" : "Off").font(.system(size: 10, weight: .medium))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor).opacity(0.4)))
            }
            .buttonStyle(.plain)

            Button(action: { module.playTestSound() }) {
                HStack(spacing: 4) {
                    Image(systemName: module.nowPlaying != nil ? "waveform" : "play.fill").foregroundColor(.blue)
                    Text("Test").font(.system(size: 10, weight: .medium))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor).opacity(0.4)))
            }
            .buttonStyle(.plain)

            Button(action: { module.stopSound() }) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill").foregroundColor(.orange)
                    Text("Stop").font(.system(size: 10, weight: .medium))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor).opacity(0.4)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Folder Actions

    private var folderActions: some View {
        HStack(spacing: 6) {
            folderButton(icon: "folder.fill", label: "Theme", color: .purple) { module.openThemeFolder() }
            folderButton(icon: "gearshape.fill", label: "Config", color: .gray) { module.openConfigFolder() }
            folderButton(icon: "house.fill", label: "Project", color: .blue) { module.openInstallFolder() }
        }
    }

    private func folderButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
                Text(label).font(.system(size: 8)).foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor).opacity(0.3)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Not Installed

    private var notInstalledView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text("DX Sounds not installed").font(.system(size: 11)).foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
    }

    private func themeEmoji(for id: String) -> String {
        switch id {
        case "quake":          return "💀"
        case "mario":          return "🍄"
        case "bollywood":      return "🎬"
        case "movie-villains": return "🦹"
        case "game-show":      return "🎰"
        case "simpsons":       return "🍩"
        case "the-office":     return "📎"
        default:               return "🎵"
        }
    }

    private func themeGradient(for id: String) -> [Color] {
        switch id {
        case "quake":          return [.red, .orange]
        case "mario":          return [.red, .blue]
        case "bollywood":      return [.orange, .yellow]
        case "movie-villains": return [.purple, .black]
        case "game-show":      return [.blue, .yellow]
        case "simpsons":       return [.yellow, .blue]
        case "the-office":     return [.gray, .blue]
        default:               return [.purple, .blue]
        }
    }

    private func modeIcon(_ mode: String) -> String {
        switch mode {
        case "arena":  return "flame.fill"
        case "casual": return "scope"
        case "zen":    return "leaf.fill"
        default:       return "music.note"
        }
    }

    private func modeColor(_ mode: String) -> Color {
        switch mode {
        case "arena":  return .red
        case "casual": return .orange
        case "zen":    return .green
        default:       return .secondary
        }
    }

    private func eventIcon(for event: String) -> String {
        if event.hasPrefix("test.")   { return event.hasSuffix(".pass") ? "checkmark.circle" : "xmark.circle" }
        if event.hasPrefix("build.")  { return event.hasSuffix(".pass") ? "hammer.fill" : "hammer" }
        if event.hasPrefix("streak.") { return "flame.fill" }
        if event.hasPrefix("combo.")  { return "bolt.fill" }
        if event.hasPrefix("git.")    { return "arrow.triangle.branch" }
        switch event {
        case "session.start": return "play.circle"
        case "first_blood":   return "drop.fill"
        case "question":      return "questionmark.circle"
        case "delete":        return "trash"
        case "error":         return "exclamationmark.triangle"
        default:              return "music.note"
        }
    }

    private func eventColor(for event: String) -> Color {
        if event.hasSuffix(".pass") { return .green }
        if event.hasSuffix(".fail") || event == "error" || event == "delete" { return .red }
        if event.hasPrefix("streak.") { return .orange }
        if event.hasPrefix("combo.")  { return .yellow }
        if event.hasPrefix("git.")    { return .purple }
        if event == "first_blood"     { return .red }
        if event == "question"        { return .blue }
        return .secondary
    }
}



// ============================================================
// 🎫 JIRA MODULE — Your tickets, boards, and filters in one place
// Now hits the Jira REST API directly — no agent, no middleman.
// Cut out the server, went straight to the source. 🎯
// Config lives in ~/.commandbar/config.json, not in code. 🔐
// ============================================================

// MARK: - Config

/// Jira configuration loaded from ~/.commandbar/config.json 🔧
struct JiraConfig: Codable {
    let baseURL: String
    let username: String
    let apiToken: String
    let projectKey: String

    /// Load config from disk — returns nil if file/key missing 📂
    /// Lives in ~/.commandbar/config.json under the "jira" key. 🏠
    static func load() -> JiraConfig? {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".commandbar/config.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jiraJSON = json["jira"],
              let jiraData = try? JSONSerialization.data(withJSONObject: jiraJSON),
              let config = try? JSONDecoder().decode(JiraConfig.self, from: jiraData) else {
            return nil
        }
        return config
    }

    /// Build the Basic auth header — base64(email:token) 🔑
    /// Atlassian's idea of "security" since 2018. At least it's not cookies. 🍪
    var authHeader: String {
        let credentials = "\(username):\(apiToken)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }
}

// MARK: - API Response Models

/// Jira search response from /rest/api/3/search/jql 📦
/// Note: the new endpoint returns nextPageToken + isLast instead of total/startAt.
/// Atlassian killed the old response shape. RIP total count, you served well. 🪦
struct JiraSearchResponse: Codable {
    let issues: [JiraIssue]
    let isLast: Bool?
    let nextPageToken: String?
}

/// A single Jira issue from the REST API 🎟️
struct JiraIssue: Codable {
    let key: String
    let fields: JiraIssueFields
}

/// Issue fields — the meat of every ticket 🥩
struct JiraIssueFields: Codable {
    let summary: String
    let status: JiraStatus
    let priority: JiraPriority?
    let issuetype: JiraIssueType?
    let updated: String?
    let assignee: JiraUser?
}

/// Status wrapper — Jira nests everything because why not 🪆
struct JiraStatus: Codable {
    let name: String
    let statusCategory: JiraStatusCategory?
}

/// Status category — the meta-status of the status. Very meta. 🤯
struct JiraStatusCategory: Codable {
    let key: String    // "new", "indeterminate", "done"
    let name: String
}

/// Priority — from Blocker (🔥) to Trivial (🤷) 📊
struct JiraPriority: Codable {
    let name: String
    let iconUrl: String?
}

/// Issue type — Bug, Story, Task, Epic, etc. 🐛📖✅🏔️
struct JiraIssueType: Codable {
    let name: String
    let iconUrl: String?
}

/// User info — just need the display name really 👤
struct JiraUser: Codable {
    let displayName: String?
}

// MARK: - View Model Ticket

/// Jira ticket representation for the UI — clean, simple, pretty 🎟️
struct JiraTicket: Identifiable {
    let id: String          // e.g. "DTVP-1234"
    let summary: String
    let status: String
    let statusCategoryKey: String  // "new", "indeterminate", "done"
    let priority: String
    let issueType: String
    let updated: String?

    /// Color coding by status category — the traffic light of productivity 🚦
    var statusColor: Color {
        switch statusCategoryKey {
        case "indeterminate": return .yellow   // In progress / active
        case "done":          return .green    // Shipped it! 🚢
        case "new":           return .blue     // Fresh off the backlog
        default:              return .secondary
        }
    }

    /// Status emoji — because raw text is boring 😎
    var statusEmoji: String {
        switch statusCategoryKey {
        case "indeterminate": return "🟡"
        case "done":          return "🟢"
        case "new":           return "🔵"
        default:              return "⚪"
        }
    }

    /// Priority emoji — the exclamation hierarchy 📊
    var priorityEmoji: String {
        switch priority.lowercased() {
        case "highest", "blocker": return "🔴"
        case "high":               return "🟠"
        case "medium":             return "🟡"
        case "low":                return "🟢"
        case "lowest":             return "⚪"
        default:                   return "⚪"
        }
    }

    /// Issue type emoji — the taxonomy of work 📋
    var typeEmoji: String {
        switch issueType.lowercased() {
        case "bug":     return "🐛"
        case "story":   return "📖"
        case "task":    return "✅"
        case "epic":    return "🏔️"
        case "sub-task": return "📎"
        default:        return "📋"
        }
    }

    /// Relative time since last update — "2h ago" not "2026-03-05T14:23:00.000+0000" 🕐
    var relativeUpdated: String? {
        guard let updated = updated else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // Try with fractional seconds first, then without — Jira can't decide which to send 🤷
        guard let date = formatter.date(from: updated) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: updated)
        }() else { return nil }

        let elapsed = Date().timeIntervalSince(date)
        switch elapsed {
        case ..<60:       return "just now"
        case ..<3600:     return "\(Int(elapsed / 60))m ago"
        case ..<86400:    return "\(Int(elapsed / 3600))h ago"
        case ..<604800:   return "\(Int(elapsed / 86400))d ago"
        default:          return "\(Int(elapsed / 604800))w ago"
        }
    }
}

// MARK: - Module

/// Jira integration — direct REST API, no agent required 🔗
/// Reads config from ~/.commandbar/config.json. Update it if creds rotate. 🔄
@MainActor
final class JiraModule: ObservableObject, CommandBarModule {
    let id = "jira"
    let sfSymbol = "ticket.fill"
    let accentColor = Color.blue

    private let logger = Logger(subsystem: "com.commandbar.app", category: "Jira")

    @Published var tickets: [JiraTicket] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isConfigured = false

    private var config: JiraConfig?

    /// Strip label — compact summary for the thin bar 📏
    var stripLabel: String {
        if isLoading { return "..." }
        if !isConfigured { return "!" }
        if let err = errorMessage { return err.hasPrefix("VPN") ? "VPN" : "err" }
        let active = tickets.filter { $0.statusCategoryKey == "indeterminate" }.count
        return active > 0 ? "\(active)/\(tickets.count)" : "\(tickets.count)"
    }

    /// Base URL for building links — falls back to empty string 🔗
    var jiraBaseURL: String { config?.baseURL ?? "https://paypal.atlassian.net" }

    /// Project key for board links 📋
    var projectKey: String { config?.projectKey ?? "DTVP" }

    /// Tickets grouped by status category — the kanban in your menu bar 📊
    var ticketsByStatus: [(status: String, tickets: [JiraTicket])] {
        let grouped = Dictionary(grouping: tickets, by: { $0.status })
        // Order: active stuff first, then new, then done 🏃‍♂️→🆕→✅
        let statusOrder = tickets.map { $0.status }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            .sorted { lhs, rhs in
                let lhsCat = tickets.first(where: { $0.status == lhs })?.statusCategoryKey ?? ""
                let rhsCat = tickets.first(where: { $0.status == rhs })?.statusCategoryKey ?? ""
                let order = ["indeterminate": 0, "new": 1, "done": 2]
                return (order[lhsCat] ?? 3) < (order[rhsCat] ?? 3)
            }
        return statusOrder.compactMap { status in
            guard let group = grouped[status], !group.isEmpty else { return nil }
            return (status: status, tickets: group)
        }
    }

    /// Refresh — load config + fetch tickets from Jira REST API 🔄
    func refresh() async {
        isLoading = true
        errorMessage = nil

        // Reload config every refresh in case it was updated 📂
        config = JiraConfig.load()
        isConfigured = config != nil

        guard let config = config else {
            errorMessage = "No config"
            isLoading = false
            return
        }

        await fetchTickets(config: config)
        isLoading = false
    }

    /// Fetch tickets via Jira REST API v3 — the real deal, no agent proxy 🎯
    /// Uses POST /rest/api/3/search/jql (the old GET /rest/api/3/search is 410'd ☠️)
    /// JQL: assignee = currentUser() AND resolution = Unresolved
    /// Sorted by updated DESC so the freshest stuff is on top. 🍞
    private func fetchTickets(config: JiraConfig) async {
        guard let url = URL(string: "\(config.baseURL)/rest/api/3/search/jql") else {
            errorMessage = "Bad URL"
            return
        }

        // POST body — Atlassian deprecated GET search in 2025, long live POST 🪦→🐣
        let body: [String: Any] = [
            "jql": "assignee = currentUser() AND resolution = Unresolved ORDER BY updated DESC",
            "fields": ["summary", "status", "priority", "issuetype", "updated", "assignee"],
            "maxResults": 30
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "No response"
                return
            }

            switch httpResponse.statusCode {
            case 200:
                break // All good, proceed to decode 🎉
            case 401:
                errorMessage = "Auth failed"
                logger.error("Jira 401 — check API token in ~/.commandbar/config.json")
                return
            case 403:
                errorMessage = "Forbidden"
                logger.error("Jira 403 — check permissions for \(config.username)")
                return
            default:
                errorMessage = "HTTP \(httpResponse.statusCode)"
                logger.error("Jira HTTP \(httpResponse.statusCode)")
                return
            }

            let searchResponse = try JSONDecoder().decode(JiraSearchResponse.self, from: data)
            tickets = searchResponse.issues.map { issue in
                JiraTicket(
                    id: issue.key,
                    summary: issue.fields.summary,
                    status: issue.fields.status.name,
                    statusCategoryKey: issue.fields.status.statusCategory?.key ?? "undefined",
                    priority: issue.fields.priority?.name ?? "None",
                    issueType: issue.fields.issuetype?.name ?? "Task",
                    updated: issue.fields.updated
                )
            }
            logger.info("Fetched \(self.tickets.count) tickets from Jira REST API ✅")
        } catch is DecodingError {
            errorMessage = "Parse error"
            logger.error("Jira response decode failed — API format may have changed 🤷")
        } catch let error as URLError where error.code == .timedOut {
            errorMessage = "Timeout"
            logger.error("Jira request timed out — VPN connected?")
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .cannotFindHost {
            errorMessage = "VPN required"
            logger.error("Can't reach Jira — probably need VPN 🔒")
        } catch {
            errorMessage = "Failed"
            logger.error("Jira fetch failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Expanded View

/// Expanded view for the Jira module — tickets, quick actions, filters 🎪
/// Now with priority badges, type icons, and relative timestamps! ✨
struct JiraExpandedView: View {
    @ObservedObject var module: JiraModule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header 🏷️
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("Jira")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
                if module.isConfigured {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("\(module.tickets.count) tickets")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                Button(action: { Task { await module.refresh() } }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Quick actions row — your Jira shortcuts 🔌
            HStack(spacing: 6) {
                quickAction("New Ticket", icon: "plus.circle.fill", color: .green,
                           url: "\(module.jiraBaseURL)/secure/CreateIssue!default.jspa")
                quickAction("My Board", icon: "square.grid.2x2.fill", color: .blue,
                           url: "\(module.jiraBaseURL)/jira/software/c/projects/\(module.projectKey)/boards")
                quickAction("Dashboard", icon: "chart.bar.fill", color: .purple,
                           url: "\(module.jiraBaseURL)/jira/dashboards")
                quickAction("Your Work", icon: "person.fill", color: .orange,
                           url: "\(module.jiraBaseURL)/jira/your-work")
            }

            // Content area — loading / error / tickets 📋
            if module.isLoading {
                HStack {
                    ProgressView().scaleEffect(0.6)
                    Text("Fetching tickets...")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            } else if !module.isConfigured {
                configMissingView
            } else if let error = module.errorMessage {
                errorView(error)
            } else if module.tickets.isEmpty {
                HStack {
                    Image(systemName: "tray.fill").foregroundColor(.secondary)
                    Text("No unresolved tickets").font(.system(size: 11)).foregroundColor(.secondary)
                }
            } else {
                ticketListView
            }

            Divider()

            // Saved filters — quick JQL shortcuts 🔍
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 4) {
                    filterLink("Recently Updated", jql: "assignee=currentUser()+order+by+updated+DESC", icon: "clock.arrow.circlepath")
                    filterLink("In Progress", jql: "assignee=currentUser()+AND+status='In Progress'", icon: "play.circle.fill")
                    filterLink("In Review", jql: "assignee=currentUser()+AND+status='In Review'", icon: "eye.circle.fill")
                    filterLink("Sprint Planning", url: "\(module.jiraBaseURL)/jira/software/c/projects/\(module.projectKey)/boards/3456/backlog", icon: "calendar")
                    filterLink("All My Bugs", jql: "assignee=currentUser()+AND+type=Bug+AND+resolution=Unresolved", icon: "ladybug.fill")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill").font(.system(size: 11))
                    Text("Saved Filters").font(.system(size: 11, weight: .medium))
                }
            }
        }
        .padding(12)
    }

    // MARK: - Ticket List

    /// The main ticket list grouped by status — your kanban board, compressed 📊
    private var ticketListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(module.ticketsByStatus, id: \.status) { group in
                    // Status group header 🏷️
                    HStack(spacing: 4) {
                        Text(group.tickets.first?.statusEmoji ?? "⚪").font(.system(size: 10))
                        Text(group.status)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("(\(group.tickets.count))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .padding(.top, 2)

                    // Individual tickets 🎟️
                    ForEach(group.tickets) { ticket in
                        ticketRow(ticket)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A single ticket row — type icon, key, summary, priority, timestamp 📝
    private func ticketRow(_ ticket: JiraTicket) -> some View {
        Button(action: {
            if let url = URL(string: "\(module.jiraBaseURL)/browse/\(ticket.id)") {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 6) {
                // Type emoji 📋
                Text(ticket.typeEmoji)
                    .font(.system(size: 10))
                    .help(ticket.issueType)

                // Ticket key — monospaced and clickable 🔗
                Text(ticket.id)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(module.accentColor)

                // Summary — the important bit 📝
                Text(ticket.summary)
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                // Priority badge 📊
                Text(ticket.priorityEmoji)
                    .font(.system(size: 8))
                    .help(ticket.priority)

                // Relative timestamp ⏰
                if let updated = ticket.relativeUpdated {
                    Text(updated)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))
                }

                // Open link indicator ↗️
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Views

    /// Config missing state — friendly nudge to set up credentials 🔧
    private var configMissingView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "gearshape.fill").foregroundColor(.orange)
                Text("Jira not configured").font(.system(size: 11, weight: .medium))
            }
            Text("Add credentials to ~/.commandbar/config.json")
                .font(.system(size: 10)).foregroundColor(.secondary)
            Button(action: {
                // Open the config file in default editor 📂
                let configPath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".commandbar/config.json")
                NSWorkspace.shared.open(configPath)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill").font(.system(size: 9))
                    Text("Open Config").font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.blue.opacity(0.1)).cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }

    /// Error state view — tells you what went wrong 🚨
    private func errorView(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(error).font(.system(size: 11, weight: .medium))
            }
            if error.contains("VPN") || error.contains("Timeout") {
                Text("Connect to VPN and try again")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            } else if error.contains("Auth") {
                Text("Check API token in ~/.commandbar/config.json")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
    }

    /// Quick action button — compact icon + label card 🃏
    private func quickAction(_ label: String, icon: String, color: Color, url: String) -> some View {
        Button(action: { if let u = URL(string: url) { NSWorkspace.shared.open(u) } }) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(color)
                Text(label).font(.system(size: 8, weight: .medium)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(color.opacity(0.08)).cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    /// Filter link row — JQL shortcut with icon 🔗
    private func filterLink(_ label: String, jql: String? = nil, url: String? = nil, icon: String) -> some View {
        Button(action: {
            let targetURL = url ?? "\(module.jiraBaseURL)/issues/?jql=\(jql ?? "")"
            if let u = URL(string: targetURL) { NSWorkspace.shared.open(u) }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(module.accentColor).frame(width: 14)
                Text(label).font(.system(size: 11))
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 8)).foregroundColor(.secondary.opacity(0.4))
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}



// ============================================================
// 📋 CLIPBOARD TOOLS MODULE — Quick-copy text snippets
// One-click clipboard copying for frequently used text.
// Because typing the same thing over and over is for robots. 🤖
// ============================================================

/// Clipboard snippet for quick copying 📝
struct ClipboardSnippet: Identifiable {
    let id = UUID()
    let label: String
    let text: String
    let icon: String
    let color: Color
}

/// Clipboard tools module — quick-copy frequently used text snippets 📋
@MainActor
final class ClipboardToolsModule: ObservableObject, CommandBarModule {
    let id = "clipboard"
    let sfSymbol = "doc.on.clipboard.fill"
    let accentColor = Color.purple
    
    @Published var lastCopied: String?
    @Published var snippets: [ClipboardSnippet] = [
        // Passwords & Tokens 🔐
        ClipboardSnippet(label: "Test Password", text: "in98^cy7pWef7$\"", icon: "key.fill", color: .red),
        
        // Email Templates 📧
        ClipboardSnippet(label: "Thanks Email", text: "Thanks for reaching out! I'll get back to you shortly.", icon: "envelope.fill", color: .blue),
        ClipboardSnippet(label: "Meeting Follow-up", text: "Great meeting today! Here are the action items we discussed:", icon: "calendar", color: .green),
        
        // Code Snippets 💻
        ClipboardSnippet(label: "Lorem Ipsum", text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.", icon: "text.quote", color: .orange),
        ClipboardSnippet(label: "Git Branch", text: "git checkout -b feature/", icon: "arrow.triangle.branch", color: .purple),
        
        // URLs 🔗
        ClipboardSnippet(label: "GitHub", text: "https://github.com", icon: "link", color: .gray),
        ClipboardSnippet(label: "Localhost", text: "http://localhost:3000", icon: "network", color: .cyan),
        
        // Common Text ✏️
        ClipboardSnippet(label: "Shrug", text: "¯\\_(ツ)_/¯", icon: "figure.wave", color: .yellow),
        ClipboardSnippet(label: "Checkmark", text: "✓", icon: "checkmark.circle.fill", color: .green),
        ClipboardSnippet(label: "Email Sig", text: "Best regards,\n[Your Name]", icon: "signature", color: .indigo),
    ]
    
    var stripLabel: String {
        if let last = lastCopied {
            return "📋"
        }
        return "Clip"
    }
    
    func refresh() async {
        // Clipboard tools are static — nothing to refresh 🤷
    }
    
    /// Copy text to clipboard 📋
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        lastCopied = text
        
        // Clear the "just copied" indicator after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if lastCopied == text {
                lastCopied = nil
            }
        }
    }
}

// MARK: - Expanded View

/// Expanded view for Clipboard Tools — grid of quick-copy buttons 📋
struct ClipboardToolsExpandedView: View {
    @ObservedObject var module: ClipboardToolsModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header 🏷️
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("Clipboard Tools")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
                
                if let lastCopied = module.lastCopied {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Copied!")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Snippets grid 📝
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6)
            ], spacing: 6) {
                ForEach(module.snippets) { snippet in
                    snippetButton(snippet)
                }
            }
            
            Divider()
            
            // Current clipboard info 📋
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Clipboard")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                if let clipboardString = NSPasteboard.general.string(forType: .string) {
                    Text(clipboardString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    HStack {
                        Image(systemName: "tray").foregroundColor(.secondary)
                        Text("Empty").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Snippet Button
    
    private func snippetButton(_ snippet: ClipboardSnippet) -> some View {
        let justCopied = module.lastCopied == snippet.text
        
        return Button(action: {
            module.copyToClipboard(snippet.text)
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(snippet.color.opacity(justCopied ? 0.3 : 0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: justCopied ? "checkmark" : snippet.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(snippet.color)
                }
                
                Text(snippet.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(snippet.text.prefix(20) + (snippet.text.count > 20 ? "..." : ""))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(justCopied ? snippet.color.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(justCopied ? snippet.color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}


// ============================================================
// ✅ REMINDERS MODULE — Your macOS Reminders at a glance
// One-click to check off tasks. Beautiful list with priorities.
// Because todo lists should be accessible, not buried in apps. 📝
// ============================================================

// MARK: - Color Extension for Persistence

extension Color {
    /// Convert Color to hex string for storage 🎨
    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else { return "#0000FF" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    /// Create Color from hex string 🌈
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

/// A reminder from macOS Reminders 📌
struct ReminderItem: Identifiable, Codable {
    let id: String
    let title: String
    let notes: String?
    let isCompleted: Bool
    let priority: Int  // 0 = none, 1-9 = priority (lower = higher priority)
    let dueDate: Date?
    let list: String
    let listColorHex: String  // Store as hex string for Codable
    
    /// Color for UI rendering (computed from hex) 🎨
    var listColor: Color {
        Color(hex: listColorHex) ?? .blue
    }
    
    /// Priority emoji based on reminder priority 🔥
    var priorityEmoji: String {
        switch priority {
        case 1: return "🔴"  // High
        case 5: return "🟡"  // Medium
        case 9: return "🔵"  // Low
        default: return ""   // None
        }
    }
    
    /// Priority label 📊
    var priorityLabel: String {
        switch priority {
        case 1: return "High"
        case 5: return "Medium"
        case 9: return "Low"
        default: return "None"
        }
    }
    
    /// Relative due date string ⏰
    var relativeDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(dueDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(dueDate) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: now, to: dueDate)
            if let days = components.day {
                if days < 0 {
                    return "\(-days)d overdue"
                } else if days < 7 {
                    return "in \(days)d"
                } else {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    return formatter.string(from: dueDate)
                }
            }
        }
        return nil
    }
    
    /// Color for due date based on urgency 🎨
    var dueDateColor: Color {
        guard let dueDate = dueDate else { return .secondary }
        if dueDate < Date() {
            return .red  // Overdue!
        } else if Calendar.current.isDateInToday(dueDate) {
            return .orange  // Due today
        } else if Calendar.current.isDateInTomorrow(dueDate) {
            return .yellow  // Due tomorrow
        }
        return .secondary
    }
}

/// Reminders module — integrates with macOS Reminders via EventKit 📋
/// Now with smart caching — full fetch on first load, then incremental updates! 🚀
@MainActor
final class RemindersModule: ObservableObject, CommandBarModule {
    let id = "reminders"
    let sfSymbol = "checklist"
    let accentColor = Color.green
    
    private let logger = Logger(subsystem: "com.commandbar.app", category: "Reminders")
    private let eventStore = EKEventStore()
    
    @Published var reminders: [ReminderItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var authStatus: EKAuthorizationStatus = .notDetermined
    
    // Cache management 💾
    private let cacheKey = "CommandBar.RemindersCache"
    private let lastFullFetchKey = "CommandBar.RemindersLastFullFetch"
    private let fullFetchInterval: TimeInterval = 3600 // 1 hour between full fetches
    
    var hasAccess: Bool {
        if #available(macOS 14.0, *) {
            return authStatus == .fullAccess || authStatus == .writeOnly
        } else {
            return authStatus == .authorized
        }
    }
    
    var stripLabel: String {
        if isLoading { return "..." }
        if !hasAccess { return "!" }
        let incomplete = reminders.filter { !$0.isCompleted }.count
        return incomplete > 0 ? "\(incomplete)" : "0"
    }
    
    init() {
        checkAuthorizationStatus()
        loadCachedReminders() // Load from cache immediately ⚡
    }
    
    func refresh() async {
        await checkAndRequestAccess()
        if hasAccess {
            await fetchReminders(forceFullFetch: false)
        }
    }
    
    // MARK: - Cache Management
    
    /// Load reminders from UserDefaults cache 💾
    private func loadCachedReminders() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([ReminderItem].self, from: data) else {
            logger.info("No cached reminders found")
            return
        }
        reminders = cached
        logger.info("Loaded \(cached.count) reminders from cache ⚡")
    }
    
    /// Save reminders to UserDefaults cache 💾
    private func saveCachedReminders() {
        guard let data = try? JSONEncoder().encode(reminders) else {
            logger.error("Failed to encode reminders for caching")
            return
        }
        UserDefaults.standard.set(data, forKey: cacheKey)
        logger.info("Cached \(self.reminders.count) reminders 💾")
    }
    
    /// Check if we need a full fetch (1 hour since last full fetch) ⏰
    private var needsFullFetch: Bool {
        guard let lastFetch = UserDefaults.standard.object(forKey: lastFullFetchKey) as? Date else {
            return true // Never fetched before
        }
        return Date().timeIntervalSince(lastFetch) > fullFetchInterval
    }
    
    // MARK: - Authorization
    
    private func checkAuthorizationStatus() {
        authStatus = EKEventStore.authorizationStatus(for: .reminder)
    }
    
    private func checkAndRequestAccess() async {
        authStatus = EKEventStore.authorizationStatus(for: .reminder)
        
        if authStatus == .notDetermined {
            do {
                let granted = try await eventStore.requestAccess(to: .reminder)
                await MainActor.run {
                    if #available(macOS 14.0, *) {
                        authStatus = granted ? .fullAccess : .denied
                    } else {
                        authStatus = granted ? .authorized : .denied
                    }
                }
            } catch {
                logger.error("Failed to request reminders access: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Access denied"
                }
            }
        }
    }
    
    // MARK: - Fetch Reminders
    
    /// Smart fetch: full fetch every hour, incremental updates in between 🧠
    private func fetchReminders(forceFullFetch: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        let calendars = eventStore.calendars(for: .reminder)
        let shouldDoFullFetch = forceFullFetch || needsFullFetch
        
        if shouldDoFullFetch {
            // Full fetch — get EVERYTHING (completed + incomplete) 📦
            logger.info("Performing FULL fetch of all reminders...")
            await performFullFetch(calendars: calendars)
            UserDefaults.standard.set(Date(), forKey: lastFullFetchKey)
        } else {
            // Incremental fetch — just incomplete reminders for quick updates ⚡
            logger.info("Performing INCREMENTAL fetch (incomplete only)...")
            await performIncrementalFetch(calendars: calendars)
        }
        
        saveCachedReminders()
        isLoading = false
    }
    
    /// Fetch ALL reminders (completed and incomplete) — heavy but complete 📦
    private func performFullFetch(calendars: [EKCalendar]) async {
        let predicate = eventStore.predicateForReminders(in: calendars)
        
        let ekReminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        reminders = convertAndSort(ekReminders)
        logger.info("Full fetch complete: \(self.reminders.count) total reminders 📦")
    }
    
    /// Fetch only INCOMPLETE reminders and merge with cached completed ones ⚡
    private func performIncrementalFetch(calendars: [EKCalendar]) async {
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )
        
        let ekReminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        let incompleteItems = convertAndSort(ekReminders)
        
        // Keep cached completed reminders, replace incomplete ones ♻️
        let cachedCompleted = reminders.filter { $0.isCompleted }
        reminders = (incompleteItems + cachedCompleted).sorted { lhs, rhs in
            // Incomplete tasks first
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            
            // Then by priority
            if lhs.priority != rhs.priority {
                if lhs.priority == 0 { return false }
                if rhs.priority == 0 { return true }
                return lhs.priority < rhs.priority
            }
            
            // Then by due date
            if let lhsDate = lhs.dueDate, let rhsDate = rhs.dueDate {
                return lhsDate < rhsDate
            } else if lhs.dueDate != nil {
                return true
            } else if rhs.dueDate != nil {
                return false
            }
            
            return lhs.title < rhs.title
        }
        
        logger.info(
            "Incremental fetch: \(incompleteItems.count) incomplete + \(cachedCompleted.count) cached = \(self.reminders.count) total ⚡")
        
        
    }
    
    
    
    /// Convert EKReminders to ReminderItems and sort them 🔄
    private func convertAndSort(_ ekReminders: [EKReminder]) -> [ReminderItem] {
        let items = ekReminders.map { reminder -> ReminderItem in
            // Convert calendar color to hex string
            let calendarColorHex: String
            if let components = reminder.calendar.cgColor.components, components.count >= 3 {
                let r = Int(components[0] * 255)
                let g = Int(components[1] * 255)
                let b = Int(components[2] * 255)
                calendarColorHex = String(format: "#%02X%02X%02X", r, g, b)
            } else {
                calendarColorHex = "#0000FF"  // Default blue
            }
            
            return ReminderItem(
                id: reminder.calendarItemIdentifier,
                title: reminder.title ?? "Untitled",
                notes: reminder.notes,
                isCompleted: reminder.isCompleted,
                priority: reminder.priority,
                dueDate: reminder.dueDateComponents?.date,
                list: reminder.calendar.title,
                listColorHex: calendarColorHex
            )
        }
        () 
        // Sort: incomplete first, then by priority, then by due date
        return items.sorted { lhs, rhs in
            // Incomplete tasks first
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            
            // Then by priority (lower number = higher priority)
            if lhs.priority != rhs.priority {
                if lhs.priority == 0 { return false }  // No priority goes last
                if rhs.priority == 0 { return true }
                return lhs.priority < rhs.priority
            }
            
            // Then by priority (lower number = higher priority)
            if lhs.priority != rhs.priority {
                if lhs.priority == 0 { return false }  // No priority goes last
                if rhs.priority == 0 { return true }
                return lhs.priority < rhs.priority
            }
            
            // Then by due date (soonest first)
            if let lhsDate = lhs.dueDate, let rhsDate = rhs.dueDate {
                return lhsDate < rhsDate
            } else if lhs.dueDate != nil {
                return true
            } else if rhs.dueDate != nil {
                return false
            }
            
            return lhs.title < rhs.title
        }
    }
    
    // MARK: - Actions
    
    /// Toggle completion status of a reminder ✅
    func toggleCompletion(for reminderId: String) {
        guard let ekReminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            logger.error("Reminder not found: \(reminderId)")
            return
        }
        
        ekReminder.isCompleted = !ekReminder.isCompleted
        
        do {
            try eventStore.save(ekReminder, commit: true)
            logger.info("Toggled reminder completion: \(ekReminder.title ?? "")")
            
            // Update local state and cache 💾
            if let index = reminders.firstIndex(where: { $0.id == reminderId }) {
                let updated = reminders[index]
                reminders[index] = ReminderItem(
                    id: updated.id,
                    title: updated.title,
                    notes: updated.notes,
                    isCompleted: !updated.isCompleted,
                    priority: updated.priority,
                    dueDate: updated.dueDate,
                    list: updated.list,
                    listColorHex: updated.listColorHex
                )
                saveCachedReminders() // Save to cache immediately after toggling
            }
        } catch {
            logger.error("Failed to save reminder: \(error.localizedDescription)")
        }
    }
    
    /// Open Reminders app 📱
    func openRemindersApp() {
        NSWorkspace.shared.launchApplication("Reminders")
    }
    
    /// Force a full refresh of ALL reminders 🔄
    func forceFullRefresh() async {
        await checkAndRequestAccess()
        if hasAccess {
            await fetchReminders(forceFullFetch: true)
        }
    }
}

// MARK: - Expanded View

/// Expanded view for Reminders — beautiful list with checkboxes and metadata 📋
struct RemindersExpandedView: View {
    @ObservedObject var module: RemindersModule
    @State private var showCompleted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header 🏷️
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("Reminders")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
                
                if module.hasAccess {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("\(incompleteCount) active")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                
                // Refresh button with option-click for full refresh 🔄
                Menu {
                    Button("Quick Refresh (Incomplete)") {
                        Task { await module.refresh() }
                    }
                    Button("Full Refresh (All)") {
                        Task { await module.forceFullRefresh() }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20, height: 20)
            }
            
            Divider()
            
            // Content area 📋
            if module.isLoading {
                HStack {
                    ProgressView().scaleEffect(0.6)
                    Text("Loading reminders...")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            } else if module.authStatus != .authorized {
                unauthorizedView
            } else if let error = module.errorMessage {
                errorView(error)
            } else if module.reminders.isEmpty {
                emptyStateView
            } else {
                reminderListView
            }
            
            Divider()
            
            // Footer actions 🔗
            HStack(spacing: 6) {
                Button(action: { module.openRemindersApp() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "app.fill").font(.system(size: 10))
                        Text("Open Reminders App").font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(Color.green.opacity(0.1)).cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: { withAnimation { showCompleted.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: showCompleted ? "eye.slash.fill" : "eye.fill").font(.system(size: 10))
                        Text(showCompleted ? "Hide Done" : "Show Done").font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1)).cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }
    
    // MARK: - Reminder List
    
    private var reminderListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(filteredReminders) { reminder in
                    reminderRow(reminder)
                }
            }
        }
        .frame(maxHeight: 400)
    }
    
    /// A single reminder row with checkbox, title, metadata ✅
    private func reminderRow(_ reminder: ReminderItem) -> some View {
        HStack(spacing: 8) {
            // Checkbox ✅
            Button(action: {
                module.toggleCompletion(for: reminder.id)
            }) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(reminder.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                // Title + Priority 📝
                HStack(spacing: 4) {
                    if !reminder.priorityEmoji.isEmpty {
                        Text(reminder.priorityEmoji).font(.system(size: 10))
                    }
                    
                    Text(reminder.title)
                        .font(.system(size: 11, weight: reminder.isCompleted ? .regular : .medium))
                        .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                        .strikethrough(reminder.isCompleted)
                    
                    Spacer()
                }
                
                // Metadata: list, due date, notes indicator 📊
                HStack(spacing: 6) {
                    // List badge 🏷️
                    HStack(spacing: 2) {
                        Circle().fill(reminder.listColor).frame(width: 6, height: 6)
                        Text(reminder.list)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    
                    // Due date ⏰
                    if let dueDate = reminder.relativeDueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.system(size: 8))
                                .foregroundColor(reminder.dueDateColor)
                            Text(dueDate)
                                .font(.system(size: 9))
                                .foregroundColor(reminder.dueDateColor)
                        }
                    }
                    
                    // Notes indicator 📝
                    if reminder.notes != nil {
                        Image(systemName: "note.text")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(reminder.isCompleted ? Color.secondary.opacity(0.05) : Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
    }
    
    // MARK: - Helper Views
    
    /// Unauthorized state — prompt to grant access 🔐
    private var unauthorizedView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "lock.fill").foregroundColor(.orange)
                Text("Access Required").font(.system(size: 11, weight: .medium))
            }
            Text("CommandBar needs permission to access your Reminders.")
                .font(.system(size: 10)).foregroundColor(.secondary)
            Button(action: {
                // Open System Settings to Privacy & Security
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "gear").font(.system(size: 9))
                    Text("Open System Settings").font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.orange.opacity(0.1)).cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }
    
    /// Error state 🚨
    private func errorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(error).font(.system(size: 11, weight: .medium))
        }
    }
    
    /// Empty state — no reminders 🎉
    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green.opacity(0.5))
            Text("All done!")
                .font(.system(size: 12, weight: .semibold))
            Text("No reminders to show")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Helpers
    
    private var filteredReminders: [ReminderItem] {
        if showCompleted {
            return module.reminders
        }
        return module.reminders.filter { !$0.isCompleted }
    }
    
    private var incompleteCount: Int {
        module.reminders.filter { !$0.isCompleted }.count
    }
}


// ============================================================
// 📰 HACKER NEWS MODULE — Top stories from Hacker News
// Because staying up to date with tech news is part of the job.
// Orange site, orange accent. 🟠
// ============================================================

// MARK: - Models

/// Hacker News story from the Firebase API 📖
struct HNStory: Codable, Identifiable {
    let id: Int
    let title: String
    let url: String?
    let score: Int?
    let by: String?
    let time: Int?
    let descendants: Int?  // comment count
    
    /// Hacker News item URL — always available even for Ask HN posts 🔗
    var hnURL: String {
        "https://news.ycombinator.com/item?id=\(id)"
    }
    
    /// External link if available, otherwise HN discussion 🌐
    var destinationURL: String {
        url ?? hnURL
    }
    
    /// Domain extracted from URL — e.g. "github.com" 🏷️
    var domain: String? {
        guard let urlString = url, let url = URL(string: urlString) else { return nil }
        return url.host?.replacingOccurrences(of: "www.", with: "")
    }
    
    /// Relative time since posted — "2h ago" not "1744675200" ⏰
    var relativeTime: String {
        guard let time = time else { return "" }
        let posted = Date(timeIntervalSince1970: TimeInterval(time))
        let elapsed = Date().timeIntervalSince(posted)
        
        switch elapsed {
        case ..<60:       return "just now"
        case ..<3600:     return "\(Int(elapsed / 60))m ago"
        case ..<86400:    return "\(Int(elapsed / 3600))h ago"
        case ..<604800:   return "\(Int(elapsed / 86400))d ago"
        default:          return "\(Int(elapsed / 604800))w ago"
        }
    }
    
    /// Story type emoji — normal story vs Ask HN vs Show HN 🎯
    var typeEmoji: String {
        if title.hasPrefix("Ask HN:") { return "❓" }
        if title.hasPrefix("Show HN:") { return "🎨" }
        return "📰"
    }
}

// MARK: - Module

/// Hacker News module — fetches top stories from the Firebase API 🔥
@MainActor
final class HackerNewsModule: ObservableObject, CommandBarModule {
    let id = "hackernews"
    let sfSymbol = "newspaper.fill"
    let accentColor = Color.orange
    
    private let logger = Logger(subsystem: "com.commandbar.app", category: "HackerNews")
    
    @Published var stories: [HNStory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// Strip label — story count or loading indicator 📊
    var stripLabel: String {
        if isLoading { return "..." }
        if let _ = errorMessage { return "err" }
        return stories.isEmpty ? "HN" : "\(stories.count)"
    }
    
    /// Refresh — fetch top stories from Hacker News 🔄
    func refresh() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Step 1: Fetch top story IDs (returns array of ints) 🎯
            let topIDs = try await NetworkService.shared.fetch(
                [Int].self,
                from: "https://hacker-news.firebaseio.com/v0/topstories.json",
                timeout: 10
            )
            
            // Step 2: Fetch details for the top 30 stories 📖
            let storyIDs = Array(topIDs.prefix(30))
            var fetchedStories: [HNStory] = []
            
            // Fetch stories concurrently — speed matters! 🏎️
            await withTaskGroup(of: HNStory?.self) { group in
                for storyID in storyIDs {
                    group.addTask {
                        try? await NetworkService.shared.fetch(
                            HNStory.self,
                            from: "https://hacker-news.firebaseio.com/v0/item/\(storyID).json",
                            timeout: 5
                        )
                    }
                }
                
                for await story in group {
                    if let story = story {
                        fetchedStories.append(story)
                    }
                }
            }
            
            // Sort by score descending — best stories first 🏆
            stories = fetchedStories.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
            logger.info("Fetched \(self.stories.count) Hacker News stories ✅")
            
        } catch {
            errorMessage = "Failed to load"
            logger.error("HN fetch failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

// MARK: - Expanded View

/// Expanded view for Hacker News — story list with scores and links 📰
struct HackerNewsExpandedView: View {
    @ObservedObject var module: HackerNewsModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header 🏷️
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("Hacker News")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
                
                if !module.stories.isEmpty {
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Text("\(module.stories.count) stories")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                
                Button(action: { Task { await module.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Quick links row 🔗
            HStack(spacing: 6) {
                quickLink("Front Page", icon: "flame.fill", url: "https://news.ycombinator.com")
                quickLink("New", icon: "sparkles", url: "https://news.ycombinator.com/newest")
                quickLink("Best", icon: "star.fill", url: "https://news.ycombinator.com/best")
                quickLink("Ask", icon: "questionmark.circle.fill", url: "https://news.ycombinator.com/ask")
            }
            
            // Content area 📋
            if module.isLoading {
                VStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 40)
                            .shimmer()
                    }
                }
            } else if let error = module.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(error).font(.system(size: 11, weight: .medium))
                }
            } else if module.stories.isEmpty {
                HStack {
                    Image(systemName: "tray.fill").foregroundColor(.secondary)
                    Text("No stories loaded").font(.system(size: 11)).foregroundColor(.secondary)
                }
            } else {
                storyListView
            }
        }
        .padding(12)
    }
    
    // MARK: - Story List
    
    private var storyListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(module.stories.prefix(25)) { story in
                    storyRow(story)
                }
            }
        }
        .frame(maxHeight: 400)
    }
    
    /// A single story row — emoji, title, score, comments 📝
    private func storyRow(_ story: HNStory) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Main row: emoji + title + external link 🔗
            HStack(spacing: 6) {
                Text(story.typeEmoji).font(.system(size: 10))
                
                Button(action: {
                    if let url = URL(string: story.destinationURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text(story.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(InteractiveButtonStyle())
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            
            // Metadata row: score, author, time, comments, domain 📊
            HStack(spacing: 8) {
                // Score 🔥
                if let score = story.score {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(scoreColor(score))
                        Text("\(score)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(scoreColor(score))
                    }
                    .bounce(trigger: score > 500)
                }
                
                // Author 👤
                if let author = story.by {
                    HStack(spacing: 2) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(author)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Time ⏰
                Text(story.relativeTime)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Spacer()
                
                // Comments 💬
                if let comments = story.descendants, comments > 0 {
                    Button(action: {
                        if let url = URL(string: story.hnURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                            Text("\(comments)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                    }
                    .buttonStyle(InteractiveButtonStyle())
                }
                
                // Domain 🌐
                if let domain = story.domain {
                    Text(domain)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.03))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    /// Quick link button 🔗
    private func quickLink(_ label: String, icon: String, url: String) -> some View {
        Button(action: { if let u = URL(string: url) { NSWorkspace.shared.open(u) } }) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(.orange)
                Text(label).font(.system(size: 8, weight: .medium)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(Color.orange.opacity(0.08)).cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    /// Color code scores — hotter = more upvotes 🔥
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case ..<50:   return .secondary
        case ..<100:  return .blue
        case ..<200:  return .green
        case ..<500:  return .orange
        default:      return .red
        }
    }
}


// ============================================================
// 💼 CAREER MODULE — Your professional life dashboard
// Job applications, LinkedIn stats, networking reminders.
// Because career growth doesn't happen on autopilot. 📈
// ============================================================

/// Career opportunity tracking 💼
struct CareerOpportunity: Identifiable {
    let id = UUID()
    let company: String
    let role: String
    let status: String  // "Applied", "Interview", "Offer", "Rejected"
    let appliedDate: Date
    let nextAction: String?
    
    var statusColor: Color {
        switch status {
        case "Applied": return .blue
        case "Interview": return .orange
        case "Offer": return .green
        case "Rejected": return .gray
        default: return .secondary
        }
    }
    
    var statusEmoji: String {
        switch status {
        case "Applied": return "📧"
        case "Interview": return "🗓️"
        case "Offer": return "🎉"
        case "Rejected": return "❌"
        default: return "📋"
        }
    }
}

/// Career module — track applications, interviews, networking 💼
@MainActor
final class CareerModule: ObservableObject, CommandBarModule {
    let id = "career"
    let sfSymbol = "briefcase.fill"
    let accentColor = Color.indigo
    
    @Published var opportunities: [CareerOpportunity] = [
        CareerOpportunity(company: "Apple", role: "Senior iOS Engineer", status: "Interview", 
                         appliedDate: Date().addingTimeInterval(-86400 * 5), nextAction: "Final round on Mon"),
        CareerOpportunity(company: "Google", role: "Staff Engineer", status: "Applied", 
                         appliedDate: Date().addingTimeInterval(-86400 * 2), nextAction: "Follow up in 3 days"),
        CareerOpportunity(company: "Meta", role: "iOS Lead", status: "Offer", 
                         appliedDate: Date().addingTimeInterval(-86400 * 14), nextAction: "Respond by Friday"),
    ]
    
    @Published var linkedInConnections = 847
    @Published var profileViews = 23
    
    var stripLabel: String {
        let active = opportunities.filter { $0.status != "Rejected" }.count
        return "\(active)"
    }
    
    func refresh() async {
        // In a real implementation, fetch from API or local storage
        // For now, static data
    }
}

/// Expanded view for Career module 💼
struct CareerExpandedView: View {
    @ObservedObject var module: CareerModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("Career")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("\(module.opportunities.count) tracked")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // LinkedIn stats
            HStack(spacing: 12) {
                VStack {
                    Image(systemName: "person.2.fill").font(.system(size: 12)).foregroundColor(.blue)
                    Text("\(module.linkedInConnections)").font(.system(size: 11, weight: .bold))
                    Text("Connections").font(.system(size: 8)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1)).cornerRadius(6)
                
                VStack {
                    Image(systemName: "eye.fill").font(.system(size: 12)).foregroundColor(.purple)
                    Text("\(module.profileViews)").font(.system(size: 11, weight: .bold))
                    Text("Profile Views").font(.system(size: 8)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1)).cornerRadius(6)
            }
            
            // Opportunities
            VStack(alignment: .leading, spacing: 4) {
                Text("Active Applications").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                
                ForEach(module.opportunities.filter { $0.status != "Rejected" }) { opp in
                    opportunityRow(opp)
                }
            }
            
            Divider()
            
            // Quick actions
            HStack(spacing: 6) {
                Button(action: { openURL("https://linkedin.com") }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 10))
                        Text("LinkedIn").font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1)).cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: { openURL("https://github.com") }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 10))
                        Text("GitHub").font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1)).cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }
    
    private func opportunityRow(_ opp: CareerOpportunity) -> some View {
        HStack(spacing: 6) {
            Text(opp.statusEmoji).font(.system(size: 10))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(opp.company).font(.system(size: 11, weight: .semibold))
                    Text("·").foregroundColor(.secondary.opacity(0.5))
                    Text(opp.role).font(.system(size: 10)).foregroundColor(.secondary)
                }
                
                if let action = opp.nextAction {
                    Text(action).font(.system(size: 9)).foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            Text(opp.status)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(opp.statusColor.opacity(0.15))
                .foregroundColor(opp.statusColor)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(4)
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}


// ============================================================
// 🔍 SPOTLIGHT MODULE — App launcher and file search
// Because macOS Spotlight is slow and bloated. This is fast. ⚡
// ============================================================

/// Launchable app or file 🚀
struct LaunchableItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: NSImage?
    let type: ItemType
    
    enum ItemType {
        case app
        case file
        case folder
    }
    
    var typeIcon: String {
        switch type {
        case .app: return "app.fill"
        case .file: return "doc.fill"
        case .folder: return "folder.fill"
        }
    }
}

/// Spotlight replacement — fast app launcher and file search 🔍
@MainActor
final class SpotlightModule: ObservableObject, CommandBarModule {
    let id = "spotlight"
    let sfSymbol = "magnifyingglass.circle.fill"
    let accentColor = Color.cyan
    
    @Published var searchQuery = ""
    @Published var recentApps: [LaunchableItem] = []
    @Published var searchResults: [LaunchableItem] = []
    
    var stripLabel: String { "Search" }
    
    init() {
        loadRecentApps()
    }
    
    func refresh() async {
        loadRecentApps()
    }
    
    /// Load recently used apps 📱
    private func loadRecentApps() {
        let workspace = NSWorkspace.shared
        let appURLs = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.bundleURL }
            .prefix(8)
        
        recentApps = appURLs.map { url in
            LaunchableItem(
                name: url.deletingPathExtension().lastPathComponent,
                path: url.path,
                icon: NSWorkspace.shared.icon(forFile: url.path),
                type: .app
            )
        }
    }
    
    /// Search for apps and files 🔍
    func search(_ query: String) {
        searchQuery = query
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // Search /Applications
        let fm = FileManager.default
        guard let apps = try? fm.contentsOfDirectory(atPath: "/Applications") else { return }
        
        let matching = apps
            .filter { $0.lowercased().contains(query.lowercased()) }
            .prefix(10)
            .map { app -> LaunchableItem in
                let path = "/Applications/\(app)"
                return LaunchableItem(
                    name: app.replacingOccurrences(of: ".app", with: ""),
                    path: path,
                    icon: NSWorkspace.shared.icon(forFile: path),
                    type: .app
                )
            }
        
        searchResults = Array(matching)
    }
    
    /// Launch an app or open a file 🚀
    func launch(_ item: LaunchableItem) {
        NSWorkspace.shared.openFile(item.path)
        //NSWorkspace.shared.open(item.path)
        searchQuery = ""
        searchResults = []
    }
}

/// Expanded view for Spotlight module 🔍
struct SpotlightExpandedView: View {
    @ObservedObject var module: SpotlightModule
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("Spotlight")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
            }
            
            Divider()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search apps and files...", text: $module.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isSearchFocused)
                    .onChange(of: module.searchQuery) { newValue in
                        module.search(newValue)
                    }
                
                if !module.searchQuery.isEmpty {
                    Button(action: { module.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .onAppear { isSearchFocused = true }
            
            // Results
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if module.searchQuery.isEmpty {
                        // Recent apps
                        Text("Recent Apps").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                        ForEach(module.recentApps) { item in
                            appRow(item)
                        }
                    } else if module.searchResults.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            Text("No results").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(module.searchResults) { item in
                            appRow(item)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(12)
    }
    
    private func appRow(_ item: LaunchableItem) -> some View {
        Button(action: { module.launch(item) }) {
            HStack(spacing: 8) {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: item.typeIcon)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                
                Text(item.name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}


// ============================================================
// ⚡ PIKACHU MODULE — Your electric companion
// Because every toolbar needs a mascot. Pika pika! ⚡
// ============================================================

/// Pikachu easter egg module ⚡
@MainActor
final class PikachuModule: ObservableObject, CommandBarModule {
    let id = "pikachu"
    let sfSymbol = "bolt.fill"
    let accentColor = Color.yellow
    
    @Published var mood: String = "happy"
    @Published var clickCount = 0
    
    var stripLabel: String { "⚡" }
    
    var pikachuEmoji: String {
        switch mood {
        case "happy": return "⚡"
        case "excited": return "✨"
        case "sleepy": return "💤"
        case "angry": return "💥"
        default: return "⚡"
        }
    }
    
    func refresh() async {
        // Pikachu doesn't need refreshing, he's always energized ⚡
    }
    
    func interact() {
        clickCount += 1
        
        switch clickCount % 5 {
        case 0: mood = "happy"
        case 1: mood = "excited"
        case 2: mood = "sleepy"
        case 3: mood = "angry"
        default: mood = "happy"
        }
    }
}

/// Expanded view for Pikachu module ⚡
struct PikachuExpandedView: View {
    @ObservedObject var module: PikachuModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                Text("Pikachu")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
            }
            
            Divider()
            
            VStack(spacing: 12) {
                Button(action: { module.interact() }) {
                    Text(module.pikachuEmoji)
                        .font(.system(size: 60))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(module.accentColor.opacity(0.1))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Text("Mood: \(module.mood.capitalized)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text("Clicks: \(module.clickCount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(12)
    }
}


// ============================================================
// ✨ SHOWCASE MODULE — The UI kitchen sink / reference template
// Every SwiftUI widget you'd want in a module, all in one place.
// It's the IKEA showroom of CommandBar modules. 🛋️
// ============================================================

/// Demo module showcasing diverse SwiftUI inputs 🎨
@MainActor
final class ShowcaseModule: ObservableObject, CommandBarModule {
    let id = "showcase"
    let sfSymbol = "sparkles"
    let accentColor = Color.pink
    var stripLabel: String { "Demo" }

    @Published var searchText = ""
    @Published var demoToggle = true
    @Published var sliderValue: Double = 0.5
    @Published var selectedMode = 0
    @Published var selectedColor = Color.blue
    @Published var progress: Double = 0.65

    let demoItems = [
        "Terminal Module", "Cosmos API", "DX Sounds", "Jira Board",
        "SwiftUI Animations", "SF Symbols", "Color Picker", "Slider Controls"
    ]

    var filteredItems: [String] {
        searchText.isEmpty ? demoItems : demoItems.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    func refresh() async { /* Showcase is static — no data to fetch 🤷 */ }
}

/// Expanded view for the Showcase module — the full UI buffet 🎪
struct ShowcaseExpandedView: View {
    @ObservedObject var module: ShowcaseModule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: module.sfSymbol)
                    .foregroundColor(module.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolEffect(.pulse, isActive: true)
                Text("Showcase")
                    .font(.system(size: DesignTokens.sectionHeaderSize, weight: .semibold))
                Spacer()
                Text("Template Module")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(3)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 🔍 Search
                    GroupBox("Search") {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            TextField("Filter items...", text: $module.searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                        }
                        .padding(6)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(4)

                        ForEach(module.filteredItems, id: \.self) { item in
                            HStack {
                                Circle().fill(module.accentColor.opacity(0.3)).frame(width: 6, height: 6)
                                Text(item).font(.system(size: 11))
                            }
                        }
                    }
                    .font(.system(size: 11))

                    // 🔘 Controls
                    GroupBox("Controls") {
                        Toggle("Dark Mode Override", isOn: $module.demoToggle)
                            .font(.system(size: 11))
                            .toggleStyle(.switch)
                            .scaleEffect(0.85, anchor: .trailing)

                        HStack {
                            Image(systemName: "speaker.fill").font(.system(size: 10))
                            Slider(value: $module.sliderValue)
                            Image(systemName: "speaker.wave.3.fill").font(.system(size: 10))
                            Text("\(Int(module.sliderValue * 100))%")
                                .font(.system(size: 10, design: .monospaced)).frame(width: 32)
                        }
                    }
                    .font(.system(size: 11))

                    // 📊 Segmented
                    GroupBox("Mode Selector") {
                        Picker("", selection: $module.selectedMode) {
                            Text("Fast").tag(0)
                            Text("Balanced").tag(1)
                            Text("Quality").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    .font(.system(size: 11))

                    // 🎨 Color picker
                    GroupBox("Color Picker") {
                        HStack {
                            ColorPicker("Accent", selection: $module.selectedColor)
                                .font(.system(size: 11))
                            Spacer()
                            ForEach([Color.blue, .purple, .pink, .orange, .green], id: \.self) { color in
                                Circle().fill(color).frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                                    .onTapGesture { module.selectedColor = color }
                            }
                        }
                    }

                    // 🔲 Button grid
                    GroupBox("Quick Actions") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                            ForEach(["star.fill", "heart.fill", "bolt.fill", "flag.fill", "bell.fill", "bookmark.fill"], id: \.self) { icon in
                                Button(action: {}) {
                                    Image(systemName: icon)
                                        .font(.system(size: 12))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(module.selectedColor.opacity(0.1))
                                        .foregroundColor(module.selectedColor)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .font(.system(size: 11))

                    // 📈 Progress ring
                    GroupBox("Progress") {
                        HStack {
                            ZStack {
                                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                                Circle()
                                    .trim(from: 0, to: module.progress)
                                    .stroke(module.selectedColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 1), value: module.progress)
                                Text("\(Int(module.progress * 100))%")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .frame(width: 44, height: 44)

                            VStack(alignment: .leading) {
                                Text("Build Progress").font(.system(size: 11, weight: .medium))
                                Text("Drag the slider below").font(.system(size: 9)).foregroundColor(.secondary)
                                Slider(value: $module.progress, in: 0...1)
                            }
                        }
                    }
                    .font(.system(size: 11))
                }
            }
            .frame(maxHeight: 350)
        }
        .padding(12)
    }
}



// ============================================================
// 🧠 APP STATE — The central nervous system of CommandBar
// Every module reports here. Every panel reads from here.
// One state to rule them all, one state to bind them. 💍
// ============================================================

/// Central observable state that coordinates all modules and panels 🎛️
@MainActor
final class AppState: ObservableObject {

    // MARK: - Panel State

    /// Whether the expanded panel is currently visible — the big reveal 🎭
    @Published var isExpanded = false

    /// Which module section is focused in the expanded panel (nil = all visible) 🔦
    @Published var focusedModuleID: String?
    
    /// Display mode: .compact (status bar) or .commandCenter (30% screen) 🎚️
    @Published var displayMode: DisplayMode = .compact
    
    enum DisplayMode {
        case compact        // Normal status bar with icons
        case commandCenter  // Large panel mode (30% screen width)
    }

    // MARK: - Modules (type-erased for the collection)

    /// Terminal module — opens iTerm2 at your project root 📂
    @Published var terminalModule = TerminalModule()

    /// Cosmos module — live AI model inventory from the mothership 🤖
    //TODO: Replace with OpenRouter
    @Published var cosmosModule = CosmosModule()

    /// DX Sounds module — remote control for your coding soundtrack 🔊
    //TODO: Replace with my own DX Sounds
    @Published var dxSoundsModule = DXSoundsRemoteModule()

    /// Showcase module — the UI kitchen sink, a reference for future modules ✨
    @Published var showcaseModule = ShowcaseModule()

    /// Jira module — tickets, boards, links — the SwiftBar replacement 🎫
    @Published var jiraModule = JiraModule()
    
    /// Hacker News module — top stories from the orange site 🟠
    @Published var hackerNewsModule = HackerNewsModule()
    
    /// Clipboard Tools module — quick-copy text snippets 📋
    @Published var clipboardModule = ClipboardToolsModule()
    
    /// Reminders module — macOS Reminders integration ✅
    @Published var remindersModule = RemindersModule()
    
    /// Career module — job tracking and professional networking 💼
    @Published var careerModule = CareerModule()
    
    /// Spotlight module — app launcher and file search 🔍
    @Published var spotlightModule = SpotlightModule()
    
    /// Pikachu module — your electric mascot ⚡
    @Published var pikachuModule = PikachuModule()
    
    /// VPN cleanup module — clears zombie VPN state on macOS 🛠️
    @Published var vpnCleanupModule = VPNCleanupModule()

    /// Launch Agent health module — brain agent status, run-now, open log 🩺
    @Published var launchAgentHealthModule = LaunchAgentHealthModule()

    /// Temporal module — Gource git-history playback + activity feed 🎬
    @Published var temporalModule = TemporalModule()

    // MARK: - Module Metadata (for strip rendering)

    //TODO: Module Info should be inside the Module itself and should be a individual struct/actor/enum with generic protocol confornmance
    /// Ordered list of module info for the strip — left to right, no drama 📏
    var moduleInfos: [(id: String, sfSymbol: String, label: String, color: Color)] {
        [
            (spotlightModule.id, spotlightModule.sfSymbol, spotlightModule.stripLabel, spotlightModule.accentColor),
            (terminalModule.id, terminalModule.sfSymbol, terminalModule.stripLabel, terminalModule.accentColor),
            (careerModule.id, careerModule.sfSymbol, careerModule.stripLabel, careerModule.accentColor),
            (jiraModule.id, jiraModule.sfSymbol, jiraModule.stripLabel, jiraModule.accentColor),
            (dxSoundsModule.id, dxSoundsModule.sfSymbol, dxSoundsModule.stripLabel, dxSoundsModule.accentColor),
            (hackerNewsModule.id, hackerNewsModule.sfSymbol, hackerNewsModule.stripLabel, hackerNewsModule.accentColor),
            (clipboardModule.id, clipboardModule.sfSymbol, clipboardModule.stripLabel, clipboardModule.accentColor),
            (remindersModule.id, remindersModule.sfSymbol, remindersModule.stripLabel, remindersModule.accentColor),
            (cosmosModule.id, cosmosModule.sfSymbol, cosmosModule.stripLabel, cosmosModule.accentColor),
            (vpnCleanupModule.id, vpnCleanupModule.sfSymbol, vpnCleanupModule.stripLabel, vpnCleanupModule.accentColor),
            (launchAgentHealthModule.id, launchAgentHealthModule.sfSymbol, launchAgentHealthModule.stripLabel, launchAgentHealthModule.accentColor),
            (temporalModule.id, temporalModule.sfSymbol, temporalModule.stripLabel, temporalModule.accentColor),
            (showcaseModule.id, showcaseModule.sfSymbol, showcaseModule.stripLabel, showcaseModule.accentColor),
            (pikachuModule.id, pikachuModule.sfSymbol, pikachuModule.stripLabel, pikachuModule.accentColor),
        ]
    }

    // MARK: - Refresh Timer

    private var refreshTimer: Timer?

    /// Start the auto-refresh timer — keeps data fresh like morning coffee ☕
    func startAutoRefresh() {
        //TODO: This seeems unoptimized
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
        // Initial refresh on launch
        Task { await refreshAll() }
    }

    /// Refresh all modules — the great synchronization event 🔄
    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.terminalModule.refresh() }
            group.addTask { await self.cosmosModule.refresh() }
            group.addTask { await self.vpnCleanupModule.refresh() }
            group.addTask { await self.launchAgentHealthModule.refresh() }
            group.addTask { await self.temporalModule.refresh() }
            group.addTask { await self.dxSoundsModule.refresh() }
            group.addTask { await self.showcaseModule.refresh() }
            group.addTask { await self.jiraModule.refresh() }
            group.addTask { await self.hackerNewsModule.refresh() }
            group.addTask { await self.clipboardModule.refresh() }
            group.addTask { await self.remindersModule.refresh() }
            group.addTask { await self.careerModule.refresh() }
            group.addTask { await self.spotlightModule.refresh() }
            group.addTask { await self.pikachuModule.refresh() }
        }
    }
    
    /// Toggle between compact status bar and command center mode 🎚️
    func toggleDisplayMode() {
        withAnimation(AnimationConstants.panelSpring) {
            displayMode = displayMode == .compact ? .commandCenter : .compact
        }
    }

    /// Toggle the expanded panel — the main event 🎪
    func toggleExpanded() {
        withAnimation(AnimationConstants.panelSpring) {
            isExpanded.toggle()
            if !isExpanded {
                focusedModuleID = nil
            }
        }
    }

    /// Collapse the expanded panel — time to hide 🫣
    func collapse() {
        withAnimation(AnimationConstants.panelSpring) {
            isExpanded = false
            focusedModuleID = nil
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }
}



// ============================================================
// 📊 STRIP CONTENT VIEW — The actual UI inside the floating strip
// Horizontal row of module icons with dot dividers.
// Compact, clickable, and always looking sharp. 🤵
// ============================================================

/// The content rendered inside the strip panel — a row of module icons 🎛️
struct StripContentView: View {
    @ObservedObject var appState: AppState
    @State private var hoveredModuleID: String?

    var body: some View {
        HStack(spacing: 0) {
            // Collapse/expand toggle button 🎚️
            Button(action: { appState.toggleDisplayMode() }) {
                Image(systemName: appState.displayMode == .commandCenter ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 6)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .help(appState.displayMode == .commandCenter ? "Collapse to status bar" : "Expand to command center")
            
            dividerDot
            
            ForEach(Array(appState.moduleInfos.enumerated()), id: \.element.id) { index, info in
                if index > 0 {
                    dividerDot
                }

                // Module icon button — click to expand/focus 🔍
                ModuleButton(
                    info: info,
                    isHovered: hoveredModuleID == info.id,
                    isFocused: appState.focusedModuleID == info.id,
                    onHover: { hoveredModuleID = $0 ? info.id : nil },
                    onTap: { handleModuleTap(info.id) }
                )
            }

            dividerDot

            // Chevron indicator — shows expand/collapse state 🔽
            ChevronButton(isExpanded: appState.isExpanded) {
                appState.toggleExpanded()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // 🌊 LIQUID GLASS — The Dynamic Island secret sauce ✨
                if #available(macOS 26.0, *) {
                    LiquidGlassBackground(
                        cornerRadius: DesignTokens.stripCornerRadius,
                        tintColor: appState.isExpanded 
                            ? NSColor.white.withAlphaComponent(0.05)
                            : nil,
                        isInteractive: true
                    )
                } else {
                    // Fallback for older macOS versions — subtle blur effect 🪟
                    Color.black.opacity(0.3)
                }
                
                // Subtle gradient overlay for depth 🎨
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Shimmer overlay when expanded ✨
                if appState.isExpanded {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(0.7)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.stripCornerRadius))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.stripCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: appState.isExpanded 
                            ? [Color.white.opacity(0.5), Color.white.opacity(0.25)]
                            : [Color.white.opacity(0.35), Color.white.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 3)
    }

    /// Dot divider between modules — the punctuation of the strip 🔹
    private var dividerDot: some View {
        Circle()
            .fill(DesignTokens.dividerColor)
            .frame(width: DesignTokens.dividerSize, height: DesignTokens.dividerSize)
            .scaleEffect(appState.isExpanded ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: appState.isExpanded)
    }

    /// Handle tap on a module icon — expand and optionally focus 🎯
    /// 🐛 Bug fix: Removed `withAnimation` wrapper — it was blocking state changes
    /// by wrapping them in an animation transaction that could conflict with the
    /// Combine-driven panel show/hide flow. Let the expanded view handle its own
    /// animations. The state change should be immediate; the visuals follow. 🏎️💨
    private func handleModuleTap(_ moduleID: String) {
        NSLog("[Strip] moduleTap: %@ | expanded=%d | focused=%@", moduleID, appState.isExpanded ? 1 : 0, appState.focusedModuleID ?? "nil")
        if appState.isExpanded && appState.focusedModuleID == moduleID {
            // Already focused on this module — collapse everything
            appState.collapse()
        } else {
            // Expand and focus on the tapped module — state change is instant,
            // the ExpandedPanelController handles the animation separately 🎬
            appState.isExpanded = true
            appState.focusedModuleID = moduleID
        }
    }
}

// MARK: - Animated Module Button

/// Individual module button with hover and press animations 🎨
struct ModuleButton: View {
    let info: (id: String, sfSymbol: String, label: String, color: Color)
    let isHovered: Bool
    let isFocused: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            // Immediate action - no delayed animation cleanup needed
            onTap()
        }) {
            HStack(spacing: 4) {
                Image(systemName: info.sfSymbol)
                    .font(.system(size: DesignTokens.stripIconSize, weight: .medium))
                    .foregroundColor(info.color)
                    .symbolEffect(.bounce, value: isFocused)
                Text(info.label)
                    .font(.system(size: DesignTokens.stripLabelSize, weight: .medium))
                    .foregroundColor(.primary.opacity(isHovered ? 1.0 : 0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isFocused ? info.color.opacity(0.15) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Animated Chevron Button

/// Chevron toggle button with rotation animation 🔽
struct ChevronButton: View {
    let isExpanded: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            Image(systemName: "chevron.up")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary.opacity(isHovered ? 0.8 : 0.6))
                .padding(.horizontal, 6)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .rotationEffect(.degrees(isExpanded ? 0 : 180))
                .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeOut(duration: 0.15), value: isExpanded)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

extension StripContentView {
    
    
    
    // ============================================================
    // 📦 EXPANDED CONTENT VIEW — The full dropdown panel content
    // Shows all module expanded views with staggered reveal animation.
    // Like unwrapping presents, but each one is a module. 🎁
    // ============================================================
    
    /// The content rendered inside the expanded panel — all modules stacked 📋
    struct ExpandedContentView: View {
        @ObservedObject var appState: AppState
        
        @State private var visibleSections: Set<String> = []
        
        private var moduleIDs: [String] {
            [appState.spotlightModule.id, appState.terminalModule.id, appState.careerModule.id,
             appState.jiraModule.id, appState.dxSoundsModule.id, appState.hackerNewsModule.id,
             appState.clipboardModule.id, appState.remindersModule.id, appState.cosmosModule.id,
             appState.vpnCleanupModule.id, appState.launchAgentHealthModule.id,
             appState.temporalModule.id,
             appState.showcaseModule.id, appState.pikachuModule.id]
        }
        
        var body: some View {
            ScrollView {
                VStack(spacing: 2) {
                    sectionWrapper(id: appState.spotlightModule.id, index: 0) {
                        SpotlightExpandedView(module: appState.spotlightModule)
                    }
                    sectionWrapper(id: appState.terminalModule.id, index: 1) {
                        TerminalExpandedView(module: appState.terminalModule)
                    }
                    sectionWrapper(id: appState.careerModule.id, index: 2) {
                        CareerExpandedView(module: appState.careerModule)
                    }
                    sectionWrapper(id: appState.jiraModule.id, index: 3) {
                        JiraExpandedView(module: appState.jiraModule)
                    }
                    sectionWrapper(id: appState.dxSoundsModule.id, index: 4) {
                        DXSoundsExpandedView(module: appState.dxSoundsModule)
                    }
                    sectionWrapper(id: appState.hackerNewsModule.id, index: 5) {
                        HackerNewsExpandedView(module: appState.hackerNewsModule)
                    }
                    sectionWrapper(id: appState.clipboardModule.id, index: 6) {
                        ClipboardToolsExpandedView(module: appState.clipboardModule)
                    }
                    sectionWrapper(id: appState.remindersModule.id, index: 7) {
                        RemindersExpandedView(module: appState.remindersModule)
                    }
                    sectionWrapper(id: appState.cosmosModule.id, index: 8) {
                        CosmosExpandedView(module: appState.cosmosModule)
                    }
                    sectionWrapper(id: appState.vpnCleanupModule.id, index: 9) {
                        VPNCleanupExpandedView(module: appState.vpnCleanupModule)
                    }
                    sectionWrapper(id: appState.launchAgentHealthModule.id, index: 10) {
                        LaunchAgentHealthExpandedView(module: appState.launchAgentHealthModule)
                    }
                    sectionWrapper(id: appState.temporalModule.id, index: 11) {
                        TemporalExpandedView(module: appState.temporalModule)
                    }
                    sectionWrapper(id: appState.showcaseModule.id, index: 12) {
                        ShowcaseExpandedView(module: appState.showcaseModule)
                    }
                    sectionWrapper(id: appState.pikachuModule.id, index: 13) {
                        PikachuExpandedView(module: appState.pikachuModule)
                    }
                }
                .padding(6)
            }
            .background(
                ZStack {
                    // 🌊 LIQUID GLASS PANEL — Expanded Dynamic Island magic ✨
                    if #available(macOS 26.0, *) {
                        LiquidGlassBackground(
                            cornerRadius: DesignTokens.expandedCornerRadius,
                            tintColor: NSColor.white.withAlphaComponent(0.03),
                            isInteractive: true
                        )
                    } else {
                        // Fallback for older macOS versions — subtle blur effect 🪟
                        Color.black.opacity(0.3)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.expandedCornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
            .onAppear {
                animateSections()
            }
            .onDisappear { visibleSections.removeAll() }
        }
        
        /// Wrap a module section with visibility/animation logic 🎲
        @ViewBuilder
        private func sectionWrapper<Content: View>(id: String, index: Int, @ViewBuilder content: () -> Content) -> some View {
            let shouldShow = appState.focusedModuleID == nil || appState.focusedModuleID == id
            let isVisible = visibleSections.contains(id)
            let isFocused = appState.focusedModuleID == id
            
            if shouldShow {
                content()
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : -10)
                    .scaleEffect(isVisible ? 1.0 : 0.95, anchor: .top)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isFocused ? Color.accentColor.opacity(0.05) : Color.clear)
                            .padding(-4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
                            .padding(-4)
                    )
                    .animation(
                        AnimationConstants.panelSpring.delay(Double(index) * AnimationConstants.staggerDelay),
                        value: isVisible
                    )
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
        }
        
        /// Trigger staggered section reveals 🌊
        private func animateSections() {
            // Simplified: show all at once instead of staggered delays
            // This eliminates 11 DispatchQueue.asyncAfter calls on every open
            for id in moduleIDs {
                _ = visibleSections.insert(id)
            }
        }
    }
    
    
    
    // ============================================================
    // 🚀 COMMANDBAR APP — The main entry point
    // Ghost mode: no dock icon, no cmd-tab. 👻
    // ============================================================
    
    @main
    struct CommandBarApp: App {
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        
        var body: some Scene {
            MenuBarExtra("CommandBar", systemImage: "command.square.fill") {
                Button("Toggle Strip") {
                    appDelegate.toggleStrip()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                
                Divider()
                
                Button(appDelegate.appState.displayMode == .commandCenter ? "Switch to Compact Mode" : "Switch to Command Center") {
                    appDelegate.appState.toggleDisplayMode()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Refresh All") {
                    Task { await appDelegate.appState.refreshAll() }
                }
                
                Divider()
                
                Toggle("Launch at Login", isOn: Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { $0 ? LaunchAtLogin.enable() : LaunchAtLogin.disable() }
                ))
                
                Divider()
                
                Button("Quit CommandBar") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
    
    // ============================================================
    // 🎩 APP DELEGATE — Manages the strip and expanded panels
    // ============================================================
    
    @MainActor
    class AppDelegate: NSObject, NSApplicationDelegate {
        
        let appState = AppState()
        private let stripPanel = StripPanel()
        private let expandedPanel = ExpandedPanelController()
        private var hotKeyMonitor: Any?
        private var cancellables = Set<AnyCancellable>()
        
        func applicationDidFinishLaunching(_ notification: Notification) {
            showStrip()
            appState.startAutoRefresh()
            setupGlobalHotkey()
            
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleClickOutside),
                name: .commandBarClickedOutside, object: nil
            )
            
            // Observe isExpanded, focusedModuleID, AND displayMode — all trigger panel updates 🎯
            // Previously only watched isExpanded, so clicking a second module did nothing
            // because isExpanded was already true and removeDuplicates() ate the event. 🍽️
            appState.$isExpanded
                .combineLatest(appState.$focusedModuleID, appState.$displayMode)
                .sink { [weak self] isExpanded, _, _ in
                    self?.syncExpandedPanel(isExpanded: isExpanded)
                }
                .store(in: &cancellables)
        }
        
        func showStrip() {
            stripPanel.show(content: StripContentView(appState: appState))
        }
        
        func toggleStrip() {
            if stripPanel.isVisible {
                stripPanel.hide()
                expandedPanel.hide()
            } else {
                showStrip()
            }
        }
        
        /// Sync the expanded panel state — show, hide, or update content 🔄
        /// Now multi-monitor aware — uses mouse location to find which strip was clicked 🖱️🖥️
        private func syncExpandedPanel(isExpanded: Bool) {
            NSLog("[Sync] isExpanded=%d | focused=%@ | panelVisible=%d", isExpanded ? 1 : 0, appState.focusedModuleID ?? "nil", expandedPanel.isVisible ? 1 : 0)
            if isExpanded {
                // Find which strip the user clicked based on mouse position 🎯
                // NSEvent.mouseLocation gives us the cursor's screen coordinates at tap time
                guard let stripFrame = stripPanel.frame(at: NSEvent.mouseLocation) else {
                    NSLog("[Sync] no strip frame found for mouse location — aborting")
                    return
                }
                
                // Tell the expanded panel about ALL strip frames so click-outside works properly 🖥️🖥️
                expandedPanel.stripFrames = stripPanel.allFrames
                
                let isCommandCenter = appState.displayMode == .commandCenter
                
                if expandedPanel.isVisible {
                    // Already visible — update content AND reposition to correct screen 🔃
                    expandedPanel.show(
                        content: ExpandedContentView(appState: appState),
                        below: stripFrame,
                        isCommandCenter: isCommandCenter
                    )
                } else {
                    // Show it fresh below the clicked strip 🎬
                    expandedPanel.show(
                        content: ExpandedContentView(appState: appState),
                        below: stripFrame,
                        isCommandCenter: isCommandCenter
                    )
                }
            } else {
                expandedPanel.hide()
            }
        }
        
        @objc private func handleClickOutside() {
            appState.collapse()
        }
        
        private func setupGlobalHotkey() {
            hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 40 {
                    Task { @MainActor in
                        self?.appState.toggleExpanded()
                    }
                }
            }
        }
        
        deinit {
            if let monitor = hotKeyMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
