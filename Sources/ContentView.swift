import SwiftUI

struct ContentView: View {
    @State private var folderURL: URL? = nil
    @State private var fileTree: [FileTreeItem] = []
    @State private var selectedFile: URL? = nil
    @State private var singleFileMode: Bool = false
    @State private var markdownText: String = ""
    @State private var isModified: Bool = false
    @State private var sidebarWidth: CGFloat = 240
    @ObservedObject private var fileTypeSettings = FileTypeSettings.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @State private var fsEventStream: FSEventStreamRef?
    @Environment(\.controlActiveState) private var controlActiveState
    
    private let lastFolderKey = "BrainDown.lastOpenedFolder"
    
    var body: some View {
        HSplitView {
            if !singleFileMode {
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
            .background(Color(nsColor: .controlBackgroundColor))
            }
            
            // Right: Editor / Reader
            VStack(spacing: 0) {
                if selectedFile != nil {
                    if appSettings.editorMode == .read {
                        MarkdownEditorView(markdownText: $markdownText, isModified: $isModified, currentFileURL: selectedFile)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id("reader-\(appSettings.useSerifFont)")
                    } else {
                        RawEditorView(text: $markdownText, isModified: $isModified)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let testURL = URL(fileURLWithPath: "/tmp/bd-test")
                if folderURL == nil && FileManager.default.fileExists(atPath: testURL.path) {
                    setFolder(testURL)
                    // Auto-select showcase.md for testing
                    let showcase = URL(fileURLWithPath: "/tmp/bd-test/showcase.md")
                    if FileManager.default.fileExists(atPath: showcase.path) {
                        selectedFile = showcase
                    }
                }
            }
        }
        .background(WindowAccessor { window in
            window.title = windowTitle
            window.isMovableByWindowBackground = true
            window.backgroundColor = DesignTokens.isDark ? .black : .white
        })
        .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { _ in
            guard controlActiveState == .key else { return }
            openFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFolderURL)) { notification in
            if let url = notification.object as? URL {
                setFolder(url)
                if let selectFile = notification.userInfo?["selectFile"] as? URL {
                    selectedFile = selectFile
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
            guard controlActiveState == .key else { return }
            saveCurrentFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSingleFile)) { notification in
            if let url = notification.object as? URL {
                openSingleFile(url)
            } else {
                guard controlActiveState == .key else { return }
                openFilePicker()
            }
        }
        .onChange(of: fileTypeSettings.enabledExtensions) { _, _ in
            refreshTree()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fsChanged)) { _ in
            refreshTree()
        }
        .onDisappear {
            stopWatching()
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
    
    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .json]
        if panel.runModal() == .OK, let url = panel.url {
            openSingleFile(url)
        }
    }
    
    func openSingleFile(_ url: URL) {
        singleFileMode = true
        folderURL = nil
        fileTree = []
        selectedFile = url
        stopWatching()
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
        singleFileMode = false
        folderURL = url
        selectedFile = nil
        markdownText = ""
        isModified = false
        UserDefaults.standard.set(url.path, forKey: lastFolderKey)
        let settings = fileTypeSettings
        DispatchQueue.global(qos: .userInitiated).async {
            let tree = FileManager.default.filteredTree(at: url, settings: settings)
            DispatchQueue.main.async {
                self.fileTree = tree
                self.startWatching(url)
            }
        }
    }
    
    private func refreshTree() {
        guard let url = folderURL else { return }
        let settings = fileTypeSettings
        DispatchQueue.global(qos: .userInitiated).async {
            let tree = FileManager.default.filteredTree(at: url, settings: settings)
            DispatchQueue.main.async { self.fileTree = tree }
        }
    }
    
    private func startWatching(_ url: URL) {
        stopWatching()
        let paths = [url.path] as CFArray
        var context = FSEventStreamContext()
        let callback: FSEventStreamCallback = { _, _, _, _, _, _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .fsChanged, object: nil)
            }
        }
        if let stream = FSEventStreamCreate(nil, callback, &context, paths, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)) {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
            fsEventStream = stream
        }
    }
    
    private func stopWatching() {
        if let stream = fsEventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fsEventStream = nil
        }
    }
    
    private func restoreLastFolder() {
        if let path = UserDefaults.standard.string(forKey: lastFolderKey) {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return }
            let settings = fileTypeSettings
            DispatchQueue.global(qos: .userInitiated).async {
                let tree = FileManager.default.filteredTree(at: url, settings: settings)
                DispatchQueue.main.async {
                    self.folderURL = url
                    self.fileTree = tree
                    self.startWatching(url)
                }
            }
        }
    }
    
    private func loadFile(_ url: URL?) {
        guard let url = url else { return }
        
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
