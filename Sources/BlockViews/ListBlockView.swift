import AppKit

/// Renders ordered and unordered list items with proper bullet/number styling.
class ListBlockView: NSView, CopyableBlock {
    private let stackView = NSStackView()
    private(set) var copyableText: String = ""
    
    init(items: [MarkdownNode], ordered: Bool) {
        super.init(frame: .zero)
        setupView(items: items, ordered: ordered)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupView(items: [MarkdownNode], ordered: Bool) {
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = DesignTokens.sp4
        var copyableTexts: [String] = []
        
        for item in items {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = DesignTokens.sp8
            
            // Bullet / number
            let bulletLabel = NSTextField(labelWithString: "")
            bulletLabel.isEditable = false
            bulletLabel.isSelectable = false
            bulletLabel.drawsBackground = false
            bulletLabel.isBordered = false
            bulletLabel.textColor = DesignTokens.bulletColor
            bulletLabel.font = DesignTokens.bodyFont
            bulletLabel.setContentHuggingPriority(.required, for: .horizontal)
            bulletLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            if case .listItem(let isOrdered, let index) = item.type {
                bulletLabel.stringValue = isOrdered ? "\(index)." : "•"
            } else {
                bulletLabel.stringValue = ordered ? "•" : "•"
            }
            
            // Content
            let contentField = NSTextField(wrappingLabelWithString: "")
            contentField.isEditable = false
            contentField.isSelectable = false
            contentField.drawsBackground = false
            contentField.isBordered = false
            contentField.lineBreakMode = .byWordWrapping
            contentField.cell?.wraps = true
            contentField.cell?.isScrollable = false
            contentField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            let attrStr = DesignTokens.attributedString(
                from: item.inlineElements,
                font: DesignTokens.bodyFont,
                color: DesignTokens.bodyColor
            )
            contentField.attributedStringValue = attrStr
            
            let bullet = bulletLabel.stringValue
            copyableTexts.append("\(bullet) \(attrStr.string)")
            
            row.addArrangedSubview(bulletLabel)
            row.addArrangedSubview(contentField)
            
            // Make content field fill width
            contentField.translatesAutoresizingMaskIntoConstraints = false
            
            stackView.addArrangedSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
        
        addSubview(stackView)
        copyableText = copyableTexts.joined(separator: "\n")
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.sp8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
