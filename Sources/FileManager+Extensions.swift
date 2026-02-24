import Foundation

extension FileManager {
    
    /// Get file tree filtered by visible extensions
    func filteredTree(at url: URL, settings: FileTypeSettings) -> [FileTreeItem] {
        guard let contents = try? contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        // Batch resource values once
        var dirs: [(URL, String)] = []
        var files: [(URL, String)] = []
        for item in contents {
            let name = item.lastPathComponent
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir { dirs.append((item, name)) }
            else if settings.matches(item) { files.append((item, name)) }
        }
        
        dirs.sort { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
        files.sort { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
        
        var items: [FileTreeItem] = []
        
        for (dirURL, _) in dirs {
            if let compacted = compactAndBuild(url: dirURL, segments: [dirURL.lastPathComponent], settings: settings) {
                items.append(compacted)
            }
        }
        for (fileURL, _) in files {
            items.append(FileTreeItem(url: fileURL, isDirectory: false, children: []))
        }
        
        return items
    }
    
    /// Walk down single-child folder chains, then build the tree from the leaf.
    private func compactAndBuild(url: URL, segments: [String], settings: FileTypeSettings) -> FileTreeItem? {
        guard let contents = try? contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        
        var dirs: [URL] = []
        var hasFiles = false
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir { dirs.append(item) }
            else if settings.matches(item) { hasFiles = true }
        }
        
        // Compact: exactly one subfolder and zero matching files → merge
        if dirs.count == 1 && !hasFiles {
            let onlyDir = dirs[0]
            return compactAndBuild(url: onlyDir, segments: segments + [onlyDir.lastPathComponent], settings: settings)
        }
        
        let children = filteredTree(at: url, settings: settings)
        if children.isEmpty { return nil }
        
        return FileTreeItem(url: url, isDirectory: true, children: children, compactSegments: segments.count > 1 ? segments : [])
    }
}

// MARK: - File Tree Item

struct FileTreeItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool
    let children: [FileTreeItem]
    let compactSegments: [String]
    
    init(url: URL, isDirectory: Bool, children: [FileTreeItem], compactSegments: [String] = []) {
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
        self.compactSegments = compactSegments
    }
    
    var name: String { url.lastPathComponent }
    
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
    static func == (lhs: FileTreeItem, rhs: FileTreeItem) -> Bool { lhs.url == rhs.url }
}
