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
        
        // Gestalt proximity: heading starts a group, content within group is tight,
        // space between groups is large.
        //
        // Spacing strategy (applied BEFORE each block):
        //   H1/H2 before:  28pt (group break)
        //   H3    before:  20pt (sub-group break)
        //   H4-H6 before:  14pt
        //   heading after → content: 2pt (tight binding)
        //   paragraph/list/blockquote between peers: 0pt (block padding handles it)
        //   code/table before & after: 4pt extra
        //   horizontalRule: 8pt before & after
        
        var lastType: MarkdownNodeType?
        var i = 0
        while i < nodes.count {
            let node = nodes[i]
            
            // Calculate spacing before this block
            if let lastView = stackView.arrangedSubviews.last {
                let gap = spacingBetween(previous: lastType, current: node.type, isFirst: false)
                stackView.setCustomSpacing(gap, after: lastView)
            }
            
            switch node.type {
            case .heading(let level):
                let view = HeadingBlockView(node: node, level: level)
                addBlock(view, to: stackView)
                lastType = node.type
                
            case .paragraph:
                if let imageElement = node.inlineElements.first(where: { isImage($0) }),
                   case .image(let alt, let url) = imageElement.style {
                    let view = ImageBlockView(alt: alt, urlString: url, currentFileDirectory: currentFileDirectory)
                    addBlock(view, to: stackView)
                } else {
                    let view = ParagraphBlockView(node: node)
                    addBlock(view, to: stackView)
                }
                lastType = node.type
                
            case .codeBlock(let language):
                let view = CodeBlockView(node: node, language: language)
                addBlock(view, to: stackView)
                lastType = node.type
                
            case .table:
                let view = TableBlockView(node: node)
                addBlock(view, to: stackView)
                lastType = node.type
                
            case .blockquote:
                let view = BlockquoteBlockView(node: node)
                addBlock(view, to: stackView)
                lastType = node.type
                
            case .unorderedList:
                var items: [MarkdownNode] = []
                var j = i + 1
                while j < nodes.count {
                    if case .listItem(let ordered, _) = nodes[j].type, !ordered {
                        items.append(nodes[j]); j += 1
                    } else { break }
                }
                let view = ListBlockView(items: items, ordered: false)
                addBlock(view, to: stackView)
                lastType = .unorderedList
                i = j; continue
                
            case .orderedList:
                var items: [MarkdownNode] = []
                var j = i + 1
                while j < nodes.count {
                    if case .listItem(let ordered, _) = nodes[j].type, ordered {
                        items.append(nodes[j]); j += 1
                    } else { break }
                }
                let view = ListBlockView(items: items, ordered: true)
                addBlock(view, to: stackView)
                lastType = .orderedList(start: 1)
                i = j; continue
                
            case .horizontalRule:
                let view = HorizontalRuleView()
                addBlock(view, to: stackView)
                lastType = node.type
                
            case .listItem, .blank:
                break
            }
            
            i += 1
        }
    }
    
    // MARK: - Helpers
    
    private static func addBlock(_ view: NSView, to stackView: NSStackView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }
    
    private static func spacingBetween(previous: MarkdownNodeType?, current: MarkdownNodeType, isFirst: Bool) -> CGFloat {
        guard let prev = previous else { return 0 }
        
        // Heading starts a new group — large gap before
        if case .heading(let level) = current {
            switch level {
            case 1, 2: return 28
            case 3:    return 20
            default:   return 14
            }
        }
        
        // Content right after heading — tight binding
        if case .heading = prev {
            return 2
        }
        
        // Code/table — slightly more breathing room
        if case .codeBlock = current { return 4 }
        if case .table = current { return 4 }
        if case .codeBlock = prev { return 4 }
        if case .table = prev { return 4 }
        
        // Horizontal rule
        if case .horizontalRule = current { return 8 }
        if case .horizontalRule = prev { return 8 }
        
        // Default: peers within same group
        return 0
    }
    
    private static func isImage(_ element: InlineElement) -> Bool {
        if case .image = element.style { return true }
        return false
    }
}
