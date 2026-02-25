import SwiftUI
import AppKit

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum EditorMode: String, CaseIterable {
    case read = "read"
    case write = "write"
    
    var label: String {
        switch self {
        case .read: return "Read"
        case .write: return "Write"
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "BrainDown.theme")
            applyTheme()
        }
    }
    
    /// editorMode is now per-window (in ContentView @State), not global.
    /// This property is kept only for reading the initial default from UserDefaults.
    var defaultEditorMode: EditorMode {
        let saved = UserDefaults.standard.string(forKey: "BrainDown.editorMode") ?? "read"
        return EditorMode(rawValue: saved) ?? .read
    }
    
    @Published var useSerifFont: Bool {
        didSet {
            UserDefaults.standard.set(useSerifFont, forKey: "BrainDown.useSerifFont")
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "BrainDown.theme") ?? "system"
        self.theme = AppTheme(rawValue: saved) ?? .system
        self.useSerifFont = UserDefaults.standard.bool(forKey: "BrainDown.useSerifFont")
        // For non-system themes, apply immediately
        if self.theme != .system, let app = NSApp {
            app.appearance = self.theme.appearance
        }
    }
    
    /// Called from applicationDidFinishLaunching when NSApp.effectiveAppearance is reliable
    func resolveSystemAppearance() {
        guard theme == .system, let app = NSApp else { return }
        let isDark = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        app.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        for window in app.windows {
            window.backgroundColor = isDark ? .black : .white
        }
    }
    
    func applyTheme() {
        guard let app = NSApp else { return }
        if theme == .system {
            let isDark = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            app.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        } else {
            app.appearance = theme.appearance
        }
        DispatchQueue.main.async {
            for window in app.windows {
                window.backgroundColor = DesignTokens.isDark ? .black : .white
            }
            NotificationCenter.default.post(name: .themeChanged, object: nil)
        }
    }
}
