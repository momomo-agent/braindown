import AppKit

/// Renders a paragraph block with inline styling (bold, italic, code, links).
class ParagraphBlockView: NSView {
    private let textField = NSTextField(wrappingLabelWithString: "")
    
    init(node: MarkdownNode) {
        super.init(frame: .zero)
        setupView(node: node)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupView(node: MarkdownNode) {
        textField.isEditable = false
        textField.isSelectable = false
        textField.drawsBackground = false
        textField.isBordered = false
        textField.lineBreakMode = .byWordWrapping
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let attrStr = DesignTokens.attributedString(
            from: node.inlineElements,
            font: DesignTokens.bodyFont,
            color: DesignTokens.bodyColor
        )
        textField.attributedStringValue = attrStr
        
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
