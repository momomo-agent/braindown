import SwiftUI

struct ContentView: View {
    @State private var folderURL: URL? = nil
    @State private var fileTree: [FileTreeItem] = []
    @State private var selectedFile: URL? = nil
    @State private var markdownText: String = ""
    @State private var isModified: Bool = false
    @State private var sidebarWidth: CGFloat = 240
    @ObservedObject private var fileTypeSettings = FileTypeSettings.shared
    
    private let lastFolderKey = "BrainDown.lastOpenedFolder"
    
    var body: some View {
        HSplitView {
            // Left: File Tree
            VStack(spacing: 0) {
                if folderURL != nil {
                    FileTreeView(items: fileTree, selectedFile: $selectedFile, isModified: isModified)
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Open a folder to start")
                            .foregroundColor(.secondary)
                        Button("Open Folder") {
                            openFolder()
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 180, idealWidth: 240, maxWidth: 360)
            
            // Right: Editor
            VStack(spacing: 0) {
                if selectedFile != nil {
                    MarkdownEditorView(markdownText: $markdownText, isModified: $isModified, currentFileURL: selectedFile)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Select a file to edit")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 700, minHeight: 500)
        .onChange(of: selectedFile) { _, newFile in
            loadFile(newFile)
        }
        .onAppear {
            restoreLastFolder()
        }
        .background(WindowAccessor { window in
            window.title = windowTitle
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
        })
        .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { _ in
            openFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
            saveCurrentFile()
        }
        .onChange(of: fileTypeSettings.enabledExtensions) { _, _ in
            refreshTree()
        }
    }
    
    private var windowTitle: String {
        var title = "BrainDown"
        if let file = selectedFile {
            title += " — \(file.lastPathComponent)"
            if isModified { title += " •" }
        }
        return title
    }
    
    // MARK: - File Operations
    
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing Markdown files"
        
        if panel.runModal() == .OK, let url = panel.url {
            setFolder(url)
        }
    }
    
    func saveCurrentFile() {
        guard let fileURL = selectedFile, isModified else { return }
        
        do {
            try markdownText.write(to: fileURL, atomically: true, encoding: .utf8)
            isModified = false
        } catch {
            print("Failed to save: \(error)")
        }
    }
    
    private func setFolder(_ url: URL) {
        folderURL = url
        fileTree = FileManager.default.filteredTree(at: url, settings: fileTypeSettings)
        selectedFile = nil
        markdownText = ""
        isModified = false
        
        // Remember this folder
        UserDefaults.standard.set(url.path, forKey: lastFolderKey)
    }
    
    private func refreshTree() {
        guard let url = folderURL else { return }
        fileTree = FileManager.default.filteredTree(at: url, settings: fileTypeSettings)
    }
    
    private func restoreLastFolder() {
        if let path = UserDefaults.standard.string(forKey: lastFolderKey) {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                setFolder(url)
            }
        }
    }
    
    private func loadFile(_ url: URL?) {
        guard let url = url else { return }
        
        // Save current file if modified before switching
        if isModified, let currentFile = selectedFile {
            try? markdownText.write(to: currentFile, atomically: true, encoding: .utf8)
        }
        
        do {
            markdownText = try String(contentsOf: url, encoding: .utf8)
            isModified = false
        } catch {
            markdownText = "Error loading file: \(error.localizedDescription)"
            isModified = false
        }
    }
}

// MARK: - Window Accessor

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                self.callback(window)
            }
        }
    }
}
