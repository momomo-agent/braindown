// BrainDown 验证工具：用 block-based 架构离屏渲染 → PNG
// 用法: bd-verify <input.md> <output.png> [width]

import AppKit
import Foundation
import UniformTypeIdentifiers

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
        
        // Use a real offscreen window to drive layout
        let padding: CGFloat = 40
        let totalWidth = contentWidth + padding * 2
        
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: totalWidth, height: 10000),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .white
        // Order the window so the window server manages it (needed for NSTextView rendering)
        window.orderBack(nil)
        
        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        
        // Flipped document view
        let docView = FlippedClipView(frame: NSRect(x: 0, y: 0, width: totalWidth, height: 10000))
        docView.wantsLayer = true
        docView.layer?.backgroundColor = NSColor.white.cgColor
        
        scrollView.documentView = docView
        window.contentView = scrollView
        
        docView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: docView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: padding),
            stackView.widthAnchor.constraint(equalToConstant: contentWidth),
        ])
        
        // Force multiple layout passes
        docView.layoutSubtreeIfNeeded()
        stackView.layoutSubtreeIfNeeded()
        
        // Run a runloop tick to let NSTextView layout managers settle
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        docView.layoutSubtreeIfNeeded()
        stackView.layoutSubtreeIfNeeded()
        
        // Another tick
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        docView.layoutSubtreeIfNeeded()
        
        // Calculate total height
        let fittingHeight = stackView.fittingSize.height + padding * 2
        docView.frame = NSRect(x: 0, y: 0, width: totalWidth, height: fittingHeight)
        window.setContentSize(NSSize(width: totalWidth, height: fittingHeight))
        
        // Final layout
        docView.layoutSubtreeIfNeeded()
        stackView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Force all subviews to display
        func forceDisplay(_ view: NSView) {
            view.display()
            for sub in view.subviews { forceDisplay(sub) }
        }
        
        // Force NSTextViews to relayout with correct widths
        func fixTextViews(_ view: NSView) {
            if let tv = view as? NSTextView,
               let lm = tv.layoutManager,
               let tc = tv.textContainer {
                // Set container width to match current frame
                if tv.frame.width > 0 {
                    tc.containerSize = NSSize(width: tv.frame.width, height: .greatestFiniteMagnitude)
                    lm.ensureLayout(for: tc)
                }
            }
            for sub in view.subviews { fixTextViews(sub) }
        }
        
        // Multiple passes: layout → fix text → layout → display
        for _ in 0..<3 {
            docView.layoutSubtreeIfNeeded()
            stackView.layoutSubtreeIfNeeded()
            fixTextViews(docView)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        
        // Recalculate total height after text layout
        docView.layoutSubtreeIfNeeded()
        let finalHeight = stackView.fittingSize.height + padding * 2
        docView.frame = NSRect(x: 0, y: 0, width: totalWidth, height: finalHeight)
        window.setContentSize(NSSize(width: totalWidth, height: finalHeight))
        docView.layoutSubtreeIfNeeded()
        fixTextViews(docView)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        forceDisplay(docView)
        
        // Render to bitmap via cacheDisplay
        guard let bitmapRep = docView.bitmapImageRepForCachingDisplay(in: docView.bounds) else {
            print("Error: bitmapImageRepForCachingDisplay failed")
            exit(1)
        }
        docView.cacheDisplay(in: docView.bounds, to: bitmapRep)
        
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

private class FlippedClipView: NSView {
    override var isFlipped: Bool { true }
}
