import Foundation

extension FileManager {
    
    /// Get file tree filtered by visible extensions
    func filteredTree(at url: URL, settings: FileTypeSettings) -> [FileTreeItem] {
        guard let contents = try? contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var items: [FileTreeItem] = []
        
        let sorted = contents.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        
        for item in sorted {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if isDir {
                let children = filteredTree(at: item, settings: settings)
                if !children.isEmpty {
                    items.append(FileTreeItem(url: item, isDirectory: true, children: children))
                }
            } else if settings.matches(item) {
                items.append(FileTreeItem(url: item, isDirectory: false, children: []))
            }
        }
        
        return items
    }
    
    /// Legacy: markdown-only tree
    func markdownTree(at url: URL) -> [FileTreeItem] {
        filteredTree(at: url, settings: FileTypeSettings.shared)
    }
}

// MARK: - File Tree Item

struct FileTreeItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool
    let children: [FileTreeItem]
    
    var name: String { url.lastPathComponent }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: FileTreeItem, rhs: FileTreeItem) -> Bool {
        lhs.url == rhs.url
    }
}
