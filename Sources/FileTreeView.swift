import SwiftUI

struct FileTreeView: View {
    let items: [FileTreeItem]
    @Binding var selectedFile: URL?
    let isModified: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    FileTreeNodeView(item: item, selectedFile: $selectedFile, isModified: isModified, depth: 0)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            .padding(.horizontal, 12)
        }
    }
}

struct FileTreeNodeView: View {
    let item: FileTreeItem
    @Binding var selectedFile: URL?
    let isModified: Bool
    let depth: Int
    @State private var isExpanded: Bool = true
    @State private var isHovering: Bool = false
    
    var isSelected: Bool {
        selectedFile == item.url
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // Indent
                if depth > 0 {
                    Color.clear.frame(width: CGFloat(depth) * 16)
                }
                
                // Expand arrow (folders)
                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                        .frame(width: 14, height: 14)
                        .animation(.easeOut(duration: 0.15), value: isExpanded)
                } else {
                    Color.clear.frame(width: 14)
                }
                
                // Icon — simple, Notion-style
                Text(iconEmoji)
                    .font(.system(size: 13))
                    .frame(width: 18)
                
                // Filename
                Text(item.displayName)
                    .font(.system(size: 13, weight: item.isDirectory ? .medium : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer(minLength: 4)
                
                // Unsaved indicator
                if !item.isDirectory && isSelected && isModified {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .padding(.trailing, 4)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if item.isDirectory {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } else {
                    selectedFile = item.url
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }
            
            // Children
            if item.isDirectory && isExpanded {
                ForEach(item.children) { child in
                    FileTreeNodeView(item: child, selectedFile: $selectedFile, isModified: isModified, depth: depth + 1)
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        } else if isHovering {
            return Color.primary.opacity(0.04)
        }
        return .clear
    }
    
    private var iconEmoji: String {
        if item.isDirectory {
            return isExpanded ? "📂" : "📁"
        }
        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "md": return "📝"
        case "txt": return "📄"
        case "json": return "{ }"
        case "yml", "yaml": return "⚙️"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "🖼"
        case "swift": return "🔶"
        case "py": return "🐍"
        case "js", "ts": return "📜"
        default: return "📄"
        }
    }
}

// MARK: - Extensions

extension FileTreeItem {
    var optionalChildren: [FileTreeItem]? {
        isDirectory ? children : nil
    }
    
    var displayName: String {
        if isDirectory { return name }
        if name.hasSuffix(".md") {
            return String(name.dropLast(3))
        }
        return name
    }
}
