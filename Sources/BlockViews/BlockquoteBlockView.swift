import AppKit

/// Renders blockquote with a left vertical bar and muted text color.
class BlockquoteBlockView: NSView, CopyableBlock {
    private let barView = NSView()
    private let textField = NSTextField(wrappingLabelWithString: "")
    private(set) var copyableText: String = ""
    
    init(node: MarkdownNode) {
        super.init(frame: .zero)
        setupView(node: node)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupView(node: MarkdownNode) {
        // Left bar
        barView.wantsLayer = true
        barView.layer?.backgroundColor = DesignTokens.blockquoteBar.cgColor
        barView.layer?.cornerRadius = 1.5
        addSubview(barView)
        
        // Text
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
            color: DesignTokens.blockquoteText
        )
        textField.attributedStringValue = attrStr
        copyableText = attrStr.string
        addSubview(textField)
        
        barView.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            barView.leadingAnchor.constraint(equalTo: leadingAnchor),
            barView.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.sp4),
            barView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.sp4),
            barView.widthAnchor.constraint(equalToConstant: 2.5),
            
            textField.leadingAnchor.constraint(equalTo: barView.trailingAnchor, constant: DesignTokens.sp12),
            textField.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.sp4),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.sp4),
        ])
    }
    
    override func updateLayer() {
        super.updateLayer()
        barView.layer?.backgroundColor = DesignTokens.blockquoteBar.cgColor
    }
}
