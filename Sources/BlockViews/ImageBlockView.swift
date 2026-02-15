import AppKit

/// Renders an image block with optional alt text caption.
class ImageBlockView: NSView {
    private let imageView = NSImageView()
    private let captionField = NSTextField(wrappingLabelWithString: "")
    private var currentFileDirectory: URL?
    private var heightConstraint: NSLayoutConstraint?
    private var placeholderLabel: NSTextField?
    
    init(alt: String, urlString: String, currentFileDirectory: URL?) {
        self.currentFileDirectory = currentFileDirectory
        super.init(frame: .zero)
        setupView(alt: alt, urlString: urlString)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupView(alt: String, urlString: String) {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.animates = true
        addSubview(imageView)
        
        captionField.isEditable = false
        captionField.isSelectable = true
        captionField.drawsBackground = false
        captionField.isBordered = false
        captionField.alignment = .center
        captionField.font = NSFont.systemFont(ofSize: DesignTokens.bodySize - 2)
        captionField.textColor = NSColor.secondaryLabelColor
        captionField.lineBreakMode = .byWordWrapping
        captionField.cell?.wraps = true
        captionField.cell?.isScrollable = false
        captionField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(captionField)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        captionField.translatesAutoresizingMaskIntoConstraints = false
        
        let maxWidth = DesignTokens.maxContentWidth - DesignTokens.sp32
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            imageView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            imageView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
        
        if alt.isEmpty {
            captionField.isHidden = true
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        } else {
            captionField.stringValue = alt
            NSLayoutConstraint.activate([
                captionField.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: DesignTokens.sp4),
                captionField.leadingAnchor.constraint(equalTo: leadingAnchor),
                captionField.trailingAnchor.constraint(equalTo: trailingAnchor),
                captionField.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
        
        loadImage(alt: alt, urlString: urlString)
    }
    
    private func loadImage(alt: String, urlString: String) {
        var imageURL: URL?
        
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            imageURL = URL(string: urlString)
        } else if let dir = currentFileDirectory {
            imageURL = dir.appendingPathComponent(urlString)
        }
        
        guard let url = imageURL else {
            showPlaceholder(alt: alt)
            return
        }
        
        if url.isFileURL {
            if let image = NSImage(contentsOf: url) {
                setImage(image)
            } else {
                showPlaceholder(alt: alt)
            }
        } else {
            // Show placeholder while loading
            showPlaceholder(alt: "⏳ Loading...")
            
            // Use URLSession for proper redirect handling and timeout
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self,
                      let data = data,
                      error == nil,
                      let image = NSImage(data: data) else {
                    DispatchQueue.main.async {
                        self?.removePlaceholder()
                        self?.showPlaceholder(alt: alt)
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.removePlaceholder()
                    self.setImage(image)
                }
            }.resume()
        }
    }
    
    private func setImage(_ image: NSImage) {
        imageView.isHidden = false
        imageView.image = image
        let maxWidth = DesignTokens.maxContentWidth - DesignTokens.sp32
        let scale = image.size.width > maxWidth ? maxWidth / image.size.width : 1.0
        let height = image.size.height * scale
        
        // Remove old height constraint if any
        if let old = heightConstraint {
            old.isActive = false
        }
        heightConstraint = imageView.heightAnchor.constraint(equalToConstant: height)
        heightConstraint?.isActive = true
        
        // Force layout update
        invalidateIntrinsicContentSize()
        superview?.needsLayout = true
    }
    
    private func showPlaceholder(alt: String) {
        let placeholder = alt.isEmpty ? "🖼 [Image]" : "🖼 \(alt)"
        let label = NSTextField(labelWithString: placeholder)
        label.font = DesignTokens.bodyFont
        label.textColor = NSColor.secondaryLabelColor
        label.alignment = .center
        
        imageView.isHidden = true
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
        placeholderLabel = label
    }
    
    private func removePlaceholder() {
        placeholderLabel?.removeFromSuperview()
        placeholderLabel = nil
    }
}
