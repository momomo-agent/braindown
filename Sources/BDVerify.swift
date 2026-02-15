// BrainDown 验证工具：用 block-based 架构离屏渲染 → PNG
// 用法: bd-verify <input.md> <output.png> [width]

import AppKit
import Foundation
import UniformTypeIdentifiers

private class VerifyFlippedView: NSView {
    override var isFlipped: Bool { true }
}

@main
struct BDVerify {
    static func main() {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            print("Usage: bd-verify <input.md> <output.png> [width]")
            exit(1)
        }
        
        let inputPath = args[1]
        let outputPath = args[2]
        let contentWidth: CGFloat = args.count >= 4 ? CGFloat(Double(args[3]) ?? 680) : 680
        
        guard let markdown = try? String(contentsOfFile: inputPath, encoding: .utf8) else {
            print("Error: Cannot read \(inputPath)")
            exit(1)
        }
        
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        
        // Parse markdown
        let nodes = MarkdownParser.parse(markdown)
        
        // Build block views in a stack
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let fileDir = URL(fileURLWithPath: inputPath).deletingLastPathComponent()
        BlockRenderer.render(nodes: nodes, into: stackView, currentFileDirectory: fileDir)
        
        // Wrap in a container with padding
        let padding: CGFloat = 40
        let totalWidth = contentWidth + padding * 2
        
        let container = VerifyFlippedView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.cgColor
        container.addSubview(stackView)
        
        // Layout
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            stackView.widthAnchor.constraint(equalToConstant: contentWidth),
        ])
        
        // Force layout
        container.frame = NSRect(x: 0, y: 0, width: totalWidth, height: 10000)
        container.layoutSubtreeIfNeeded()
        
        let fittingHeight = stackView.fittingSize.height + padding * 2
        container.frame = NSRect(x: 0, y: 0, width: totalWidth, height: fittingHeight)
        container.layoutSubtreeIfNeeded()
        
        // Render to bitmap
        guard let bitmapRep = container.bitmapImageRepForCachingDisplay(in: container.bounds) else {
            print("Error: bitmapImageRepForCachingDisplay failed")
            exit(1)
        }
        container.cacheDisplay(in: container.bounds, to: bitmapRep)
        
        guard let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            print("Error: PNG conversion failed")
            exit(1)
        }
        
        do {
            try pngData.write(to: URL(fileURLWithPath: outputPath))
            print("OK: \(outputPath) (\(Int(totalWidth))x\(Int(fittingHeight)))")
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }
}
