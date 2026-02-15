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

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "BrainDown.theme")
            applyTheme()
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "BrainDown.theme") ?? "system"
        self.theme = AppTheme(rawValue: saved) ?? .system
        // 不在 init 里调 applyTheme，NSApp 还没准备好
        // 延迟到 runloop 空闲时执行
        DispatchQueue.main.async { [weak self] in
            self?.applyTheme()
        }
    }
    
    func applyTheme() {
        guard let app = NSApp else { return }
        app.appearance = theme.appearance
    }
}
