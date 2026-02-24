import AppKit

/// Renders heading blocks (H1-H6) with proper typography.
/// H1/H2 use Georgia serif, H3+ use system sans-serif.
class HeadingBlockView: NSView {
    private let textField = NSTextField(wrappingLabelWithString: "")
    
    init(node: MarkdownNode, level: Int) {
        super.init(frame: .zero)
        setupView(node: node, level: level)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupView(node: MarkdownNode, level: Int) {
        textField.isEditable = false
        textField.isSelectable = true
        textField.drawsBackground = false
        textField.isBordered = false
        textField.lineBreakMode = .byWordWrapping
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let font = DesignTokens.headingFont(level: level)
        let color: NSColor = level == 6 ? NSColor.secondaryLabelColor : DesignTokens.headingColor
        let lineHeight: CGFloat = level <= 2 ? 1.3 : 1.4
        
        let elements = node.inlineElements.isEmpty
            ? [InlineElement(text: node.content, style: .plain)]
            : node.inlineElements
        
        let displayElements: [InlineElement]
        if level == 6 {
            displayElements = elements.map { InlineElement(text: $0.text.uppercased(), style: $0.style) }
        } else {
            displayElements = elements
        }
        
        let attrStr = DesignTokens.attributedString(
            from: displayElements,
            font: font,
            color: color,
            lineHeightMultiple: lineHeight
        )
        textField.attributedStringValue = attrStr
        
        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // Spacing: before ≥ 3× after (proximity principle)
        let topPadding: CGFloat
        switch level {
        case 1: topPadding = DesignTokens.sp16
        case 2: topPadding = DesignTokens.sp12
        case 3: topPadding = DesignTokens.sp8
        default: topPadding = DesignTokens.sp4
        }
        
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: topAnchor, constant: topPadding),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
