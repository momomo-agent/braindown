import Foundation

// 文件类型过滤设置
class FileTypeSettings: ObservableObject {
    static let shared = FileTypeSettings()
    
    private let key = "BrainDown.visibleExtensions"
    
    // 所有可选的文件类型
    static let allTypes: [(ext: String, label: String)] = [
        ("md", "Markdown (.md)"),
        ("txt", "Text (.txt)"),
        ("json", "JSON (.json)"),
        ("yml", "YAML (.yml/.yaml)"),
        ("png", "PNG (.png)"),
        ("jpg", "JPEG (.jpg/.jpeg)"),
        ("gif", "GIF (.gif)"),
        ("svg", "SVG (.svg)"),
        ("webp", "WebP (.webp)"),
    ]
    
    // yaml 映射到 yml
    private static let aliasMap: [String: String] = ["yaml": "yml", "jpeg": "jpg"]
    
    @Published var enabledExtensions: Set<String> {
        didSet { save() }
    }
    
    private init() {
        if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
            var exts = Set(saved)
            // Migration: ensure yml is enabled (added in v0.4)
            if !exts.contains("yml") {
                let migrationKey = "BrainDown.ymlMigrated"
                if !UserDefaults.standard.bool(forKey: migrationKey) {
                    exts.insert("yml")
                    UserDefaults.standard.set(true, forKey: migrationKey)
                }
            }
            enabledExtensions = exts
        } else {
            // 默认显示 .md, .json, .yml
            enabledExtensions = ["md", "json", "yml"]
        }
    }
    
    private func save() {
        UserDefaults.standard.set(Array(enabledExtensions), forKey: key)
    }
    
    func toggle(_ ext: String) {
        if enabledExtensions.contains(ext) {
            // 至少保留一个
            if enabledExtensions.count > 1 {
                enabledExtensions.remove(ext)
            }
        } else {
            enabledExtensions.insert(ext)
        }
    }
    
    func matches(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let normalized = Self.aliasMap[ext] ?? ext
        return enabledExtensions.contains(normalized)
    }
}
