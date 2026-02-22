import AppKit

/// Maps [MarkdownNode] → NSView tree inside an NSScrollView > NSStackView.
/// This is the core of the block-based architecture.
class BlockRenderer {
    
    /// Render markdown nodes into block views, added to the given stack view.
    static func render(
        nodes: [MarkdownNode],
        into stackView: NSStackView,
        currentFileDirectory: URL?
    ) {
        // Clear existing views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        var i = 0
        while i < nodes.count {
            let node = nodes[i]
            
            switch node.type {
            case .heading(let level):
                let view = HeadingBlockView(node: node, level: level)
                let spaceBefore: CGFloat = (i == 0) ? 0 : (level <= 2 ? DesignTokens.sp24 : DesignTokens.sp16)
                if i > 0, let lastView = stackView.arrangedSubviews.last {
                    stackView.setCustomSpacing(spaceBefore, after: lastView)
                }
                addBlock(view, to: stackView, spacing: DesignTokens.sp8)
                
            case .paragraph:
                if let imageElement = node.inlineElements.first(where: { isImage($0) }),
                   case .image(let alt, let url) = imageElement.style {
                    let view = ImageBlockView(alt: alt, urlString: url, currentFileDirectory: currentFileDirectory)
                    addBlock(view, to: stackView, spacing: DesignTokens.sp8)
                } else {
                    let view = ParagraphBlockView(node: node)
                    addBlock(view, to: stackView, spacing: DesignTokens.sp8)
                }
                
            case .codeBlock(let language):
                let view = CodeBlockView(node: node, language: language)
                addBlock(view, to: stackView, spacing: DesignTokens.sp8)
                
            case .table:
                let view = TableBlockView(node: node)
                addBlock(view, to: stackView, spacing: DesignTokens.sp8)
                
            case .blockquote:
                let view = BlockquoteBlockView(node: node)
                addBlock(view, to: stackView, spacing: DesignTokens.sp8)
                
            case .unorderedList:
                // Collect following listItem nodes
                var items: [MarkdownNode] = []
                var j = i + 1
                while j < nodes.count {
                    if case .listItem(let ordered, _) = nodes[j].type, !ordered {
                        items.append(nodes[j])
                        j += 1
                    } else {
                        break
                    }
                }
                let view = ListBlockView(items: items, ordered: false)
                addBlock(view, to: stackView, spacing: DesignTokens.sp8)
                i = j
                continue
                
            case .orderedList:
                var items: [MarkdownNode] = []
                var j = i + 1
                while j < nodes.count {
                    if case .listItem(let ordered, _) = nodes[j].type, ordered {
                        items.append(nodes[j])
                        j += 1
                    } else {
                        break
                    }
                }
                let view = ListBlockView(items: items, ordered: true)
                addBlock(view, to: stackView, spacing: DesignTokens.sp8)
                i = j
                continue
                
            case .horizontalRule:
                let view = HorizontalRuleView()
                addBlock(view, to: stackView, spacing: DesignTokens.sp4)
                
            case .listItem, .blank:
                // Skip — handled by list grouping or ignored
                break
            }
            
            i += 1
        }
    }
    
    // MARK: - Helpers
    
    private static func addBlock(_ view: NSView, to stackView: NSStackView, spacing: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(view)
        
        // Full width
        view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        
        // Set custom spacing after this view
        stackView.setCustomSpacing(spacing, after: view)
    }
    
    private static func isImage(_ element: InlineElement) -> Bool {
        if case .image = element.style { return true }
        return false
    }
}
