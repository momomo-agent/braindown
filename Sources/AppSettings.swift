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
    
    @Published var editorMode: EditorMode {
        didSet {
            UserDefaults.standard.set(editorMode.rawValue, forKey: "BrainDown.editorMode")
        }
    }
    
    @Published var useSerifFont: Bool {
        didSet {
            UserDefaults.standard.set(useSerifFont, forKey: "BrainDown.useSerifFont")
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "BrainDown.theme") ?? "system"
        self.theme = AppTheme(rawValue: saved) ?? .system
        let savedMode = UserDefaults.standard.string(forKey: "BrainDown.editorMode") ?? "read"
        self.editorMode = EditorMode(rawValue: savedMode) ?? .read
        self.useSerifFont = UserDefaults.standard.bool(forKey: "BrainDown.useSerifFont")
        DispatchQueue.main.async { [weak self] in
            self?.applyTheme()
        }
    }
    
    func applyTheme() {
        guard let app = NSApp else { return }
        app.appearance = theme.appearance
    }
}
