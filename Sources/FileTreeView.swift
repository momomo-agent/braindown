import SwiftUI

struct FileTreeView: View {
    let items: [FileTreeItem]
    @Binding var selectedFile: URL?
    let isModified: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(items) { item in
                    FileTreeNodeView(item: item, selectedFile: $selectedFile, isModified: isModified, depth: 0)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
            .padding(.horizontal, 8)
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
            HStack(spacing: 0) {
                // 缩进
                if depth > 0 {
                    Color.clear.frame(width: CGFloat(depth) * 14)
                }
                
                // 展开箭头（文件夹）
                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                        .frame(width: 16, height: 16)
                        .animation(.easeOut(duration: 0.15), value: isExpanded)
                } else {
                    Color.clear.frame(width: 16)
                }
                
                // 图标
                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
                
                // 文件名
                Text(item.displayName)
                    .font(.system(size: 12.5, weight: item.isDirectory ? .medium : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer(minLength: 4)
                
                // 未保存标记
                if !item.isDirectory && isSelected && isModified {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .padding(.trailing, 2)
                }
            }
            .padding(.vertical, 3.5)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
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
            
            // 子项
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
    
    private var iconName: String {
        if item.isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "md": return "doc.text"
        case "txt": return "doc.plaintext"
        case "json": return "curlybraces"
        case "yml", "yaml": return "list.bullet.indent"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        default: return "doc"
        }
    }
    
    private var iconColor: Color {
        if item.isDirectory {
            return Color.accentColor.opacity(0.8)
        }
        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "md": return .secondary
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return .purple.opacity(0.7)
        default: return Color.secondary.opacity(0.6)
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
