import AppKit

/// Notion-quality table: rounded container, header distinction, hover row highlight,
/// auto-sizing columns, alternating row colors.
class TableBlockView: NSView {
    
    private let containerView = NSView()
    private let stackView = NSStackView()
    private var rowViews: [TableRowView] = []
    private var separatorViews: [NSView] = []
    
    init(node: MarkdownNode) {
        super.init(frame: .zero)
        setupView(node: node)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - Parse table content
    
    private func parseTable(_ content: String) -> (headers: [String], rows: [[String]])? {
        let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return nil }
        
        var dataLines: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip separator lines (|---|---|)
            let stripped = trimmed.replacingOccurrences(of: "|", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty { continue }
            dataLines.append(trimmed)
        }
        
        guard !dataLines.isEmpty else { return nil }
        
        func parseCells(_ line: String) -> [String] {
            line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        let headers = parseCells(dataLines[0])
        let rows = dataLines.dropFirst().map { parseCells($0) }
        
        return (headers, Array(rows))
    }
    
    // MARK: - Setup
    
    private func setupView(node: MarkdownNode) {
        wantsLayer = true
        
        guard let tableData = parseTable(node.content) else { return }
        let headers = tableData.headers
        let rows = tableData.rows
        let colCount = headers.count
        
        // Container — rounded with border
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = DesignTokens.tableBorder.cgColor
        containerView.layer?.backgroundColor = DesignTokens.tableOddRow.cgColor
        addSubview(containerView)
        
        // Stack of rows
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        containerView.addSubview(stackView)
        
        // Header row
        let headerRow = TableRowView(
            cells: headers,
            colCount: colCount,
            isHeader: true,
            rowIndex: 0
        )
        stackView.addArrangedSubview(headerRow)
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        rowViews.append(headerRow)
        
        // Header separator
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = DesignTokens.tableBorder.cgColor
        stackView.addArrangedSubview(sep)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        sep.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        separatorViews.append(sep)
        
        // Data rows
        for (idx, row) in rows.enumerated() {
            let rowView = TableRowView(
                cells: row,
                colCount: colCount,
                isHeader: false,
                rowIndex: idx
            )
            stackView.addArrangedSubview(rowView)
            rowView.translatesAutoresizingMaskIntoConstraints = false
            rowView.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            rowViews.append(rowView)
            
            // Thin separator between data rows (not after last)
            if idx < rows.count - 1 {
                let lineSep = NSView()
                lineSep.wantsLayer = true
                lineSep.layer?.backgroundColor = DesignTokens.tableBorder.withAlphaComponent(0.5).cgColor
                stackView.addArrangedSubview(lineSep)
                lineSep.translatesAutoresizingMaskIntoConstraints = false
                lineSep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                lineSep.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
                separatorViews.append(lineSep)
            }
        }
        
        // Layout
        containerView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }
    
    override func updateLayer() {
        super.updateLayer()
        containerView.layer?.borderColor = DesignTokens.tableBorder.cgColor
        containerView.layer?.backgroundColor = DesignTokens.tableOddRow.cgColor
        for sep in separatorViews {
            sep.layer?.backgroundColor = DesignTokens.tableBorder.cgColor
        }
    }
}

// MARK: - Table Row View

class TableRowView: NSView {
    private let cellStack = NSStackView()
    private var isHeader: Bool
    private var rowIndex: Int
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    
    init(cells: [String], colCount: Int, isHeader: Bool, rowIndex: Int) {
        self.isHeader = isHeader
        self.rowIndex = rowIndex
        super.init(frame: .zero)
        setupRow(cells: cells, colCount: colCount)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupRow(cells: [String], colCount: Int) {
        wantsLayer = true
        applyRowBackground()
        
        cellStack.orientation = .horizontal
        cellStack.alignment = .top
        cellStack.spacing = 0
        cellStack.distribution = .fillEqually
        addSubview(cellStack)
        
        for i in 0..<colCount {
            let cellText = i < cells.count ? cells[i] : ""
            let cellView = createCellView(text: cellText)
            cellStack.addArrangedSubview(cellView)
        }
        
        cellStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cellStack.topAnchor.constraint(equalTo: topAnchor),
            cellStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            cellStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            cellStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        updateTrackingAreas()
    }
    
    private func createCellView(text: String) -> NSView {
        let container = NSView()
        let label = NSTextField(wrappingLabelWithString: text)
        label.isEditable = false
        label.isSelectable = true
        label.drawsBackground = false
        label.isBordered = false
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let font: NSFont = isHeader
            ? NSFont.systemFont(ofSize: DesignTokens.bodySize - 1, weight: .semibold)
            : NSFont.systemFont(ofSize: DesignTokens.bodySize - 1, weight: .regular)
        
        let color: NSColor = isHeader
            ? (DesignTokens.isDark ? NSColor(white: 0.9, alpha: 1) : NSColor(white: 0.15, alpha: 1))
            : DesignTokens.bodyColor
        
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineHeightMultiple = 1.3
        
        label.attributedStringValue = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paraStyle
        ])
        
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.sp8),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.sp12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.sp12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.sp8),
        ])
        
        return container
    }
    
    private func applyRowBackground() {
        if isHeader {
            layer?.backgroundColor = DesignTokens.tableHeaderBackground.cgColor
        } else if isHovered {
            layer?.backgroundColor = DesignTokens.tableHoverRow.cgColor
        } else {
            layer?.backgroundColor = (rowIndex % 2 == 0 ? DesignTokens.tableEvenRow : DesignTokens.tableOddRow).cgColor
        }
    }
    
    // MARK: - Hover
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        guard !isHeader else { return }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard !isHeader else { return }
        isHovered = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            applyRowBackground()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard !isHeader else { return }
        isHovered = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            applyRowBackground()
        }
    }
    
    override func updateLayer() {
        super.updateLayer()
        applyRowBackground()
    }
}
