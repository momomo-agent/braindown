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
        
        let sorted = contents.sorted { a, b in
            let aDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let bDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if aDir != bDir { return aDir }
            return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
        }
        
        for item in sorted {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if isDir {
                // Build compacted folder chain from raw filesystem (not pre-compacted children)
                let compacted = compactAndBuild(url: item, segments: [item.lastPathComponent], settings: settings)
                if let compacted = compacted {
                    items.append(compacted)
                }
            } else if settings.matches(item) {
                items.append(FileTreeItem(url: item, isDirectory: false, children: []))
            }
        }
        
        return items
    }
    
    /// Walk down single-child folder chains, then build the tree from the leaf.
    private func compactAndBuild(url: URL, segments: [String], settings: FileTypeSettings) -> FileTreeItem? {
        guard let contents = try? contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        
        let sorted = contents.sorted { a, b in
            let aDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let bDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if aDir != bDir { return aDir }
            return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
        }
        
        // Separate dirs and files
        var dirs: [URL] = []
        var files: [URL] = []
        for item in sorted {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir { dirs.append(item) }
            else if settings.matches(item) { files.append(item) }
        }
        
        // Compact: exactly one subfolder and zero files → merge
        if dirs.count == 1 && files.isEmpty {
            let onlyDir = dirs[0]
            let newSegments = segments + [onlyDir.lastPathComponent]
            return compactAndBuild(url: onlyDir, segments: newSegments, settings: settings)
        }
        
        // Build children normally from this level
        let children = filteredTree(at: url, settings: settings)
        if children.isEmpty { return nil }
        
        return FileTreeItem(url: url, isDirectory: true, children: children, compactSegments: segments.count > 1 ? segments : [])
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
    /// Segments of compacted folder names (e.g. ["models", "params"] → "models / params")
    let compactSegments: [String]
    
    init(url: URL, isDirectory: Bool, children: [FileTreeItem], compactSegments: [String] = []) {
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
        self.compactSegments = compactSegments
    }
    
    var name: String { url.lastPathComponent }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: FileTreeItem, rhs: FileTreeItem) -> Bool {
        lhs.url == rhs.url
    }
}
