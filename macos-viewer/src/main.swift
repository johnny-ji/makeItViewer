import Cocoa
import WebKit
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var currentFilePath: String?
    var fileSource: DispatchSourceFileSystemObject?
    var fileDescriptor: Int32 = -1
    var isWebViewReady = false
    var pendingFilePath: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[MarkdownViewer] applicationDidFinishLaunching started")
        setupMainMenu()
        setupWindow()
        setupWebView()

        // 检查命令行参数中是否传入了文件
        let args = CommandLine.arguments
        print("[MarkdownViewer] args: \(args)")
        if args.count > 1 {
            let candidate = args[1]
            if !candidate.hasPrefix("-") && FileManager.default.fileExists(atPath: candidate) {
                print("[MarkdownViewer] opening candidate: \(candidate)")
                openFile(path: (candidate as NSString).expandingTildeInPath)
            }
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        print("[MarkdownViewer] application openFile: \(filename)")
        if window == nil || !isWebViewReady {
            pendingFilePath = filename
        } else {
            openFile(path: filename)
        }
        return true
    }

    func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. App 菜单
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 Markdown 视觉预览器", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏 Markdown 预览器", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. 文件菜单
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(withTitle: "打开文件...", action: #selector(openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "重新加载", action: #selector(reloadCurrentFile(_:)), keyEquivalent: "r")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. 视图菜单
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "视图")
        viewMenu.addItem(withTitle: "放大", action: #selector(zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "缩小", action: #selector(zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "实际大小", action: #selector(resetZoom(_:)), keyEquivalent: "0")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "切换全景/标准模式", action: #selector(toggleFullWidth(_:)), keyEquivalent: "d")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }

    func setupWindow() {
        let rect = NSRect(x: 120, y: 100, width: 1320, height: 880)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 800, height: 600)
        window.title = "Markdown & Mermaid 视觉预览器"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.registerForDraggedTypes([.fileURL])
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setupWebView() {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "openFileDialog")
        userContentController.add(self, name: "saveImage")
        userContentController.add(self, name: "saveSvg")
        config.userContentController = userContentController
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        window.contentView!.addSubview(webView)

        // 加载打包的资源 HTML
        let bundlePath = Bundle.main.resourcePath ?? "."
        var htmlUrl = URL(fileURLWithPath: bundlePath).appendingPathComponent("index.html")
        if !FileManager.default.fileExists(atPath: htmlUrl.path) {
            // 开发阶段兜底查找
            htmlUrl = URL(fileURLWithPath: "tools/macos-viewer/resources/index.html")
        }
        let dirUrl = htmlUrl.deletingLastPathComponent()
        webView.loadFileURL(htmlUrl, allowingReadAccessTo: dirUrl)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isWebViewReady = true
        if let pending = pendingFilePath {
            pendingFilePath = nil
            openFile(path: pending)
        }
    }

    // 处理网页端发来的消息
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "openFileDialog" {
            openDocument(self)
        } else if message.name == "saveImage" {
            handleSaveImage(message.body)
        } else if message.name == "saveSvg" {
            handleSaveSvg(message.body)
        }
    }

    func handleSaveImage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let base64String = dict["base64"] as? String else {
            return
        }

        let cleanBase64 = base64String.replacingOccurrences(of: "^data:image/\\w+;base64,", with: "", options: .regularExpression)
        guard let imageData = Data(base64Encoded: cleanBase64) else {
            print("[MarkdownViewer] 无法解码 Base64 图片数据")
            return
        }

        // 1. 写入剪贴板 (永远优先写入剪贴板，方便即时粘贴)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(imageData, forType: .png)

        let action = (dict["action"] as? String) ?? "save"
        if action == "copy" {
            let js = "showToast('✅ 已复制高清 PNG 到剪贴板，可直接在飞书/微信/PPT 中粘贴 (Cmd+V)！');"
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript(js, completionHandler: nil)
            }
            return
        }

        // 2. 导出文件：调起 macOS 原生 NSSavePanel
        let defaultName = (dict["filename"] as? String) ?? "chart.png"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        panel.title = "导出 PNG 图片"
        panel.prompt = "保存"
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType.png]
        } else {
            panel.allowedFileTypes = ["png"]
        }

        panel.beginSheetModal(for: self.window) { [weak self] response in
            if response == .OK, let url = panel.url {
                do {
                    try imageData.write(to: url)
                    let safeName = url.lastPathComponent.replacingOccurrences(of: "'", with: "\\'")
                    let js = "showToast('✅ 导出成功，已保存至: \(safeName)');"
                    DispatchQueue.main.async {
                        self?.webView.evaluateJavaScript(js, completionHandler: nil)
                    }
                } catch {
                    print("写入图片文件失败: \(error)")
                }
            }
        }
    }

    func handleSaveSvg(_ body: Any) {
        guard let dict = body as? [String: Any],
              let svgString = dict["svg"] as? String,
              let svgData = svgString.data(using: .utf8) else {
            return
        }

        let defaultName = (dict["filename"] as? String) ?? "chart.svg"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        panel.title = "导出 SVG 矢量图"
        panel.prompt = "保存"
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [UTType.svg]
        } else {
            panel.allowedFileTypes = ["svg"]
        }

        panel.beginSheetModal(for: self.window) { [weak self] response in
            if response == .OK, let url = panel.url {
                do {
                    try svgData.write(to: url)
                    let safeName = url.lastPathComponent.replacingOccurrences(of: "'", with: "\\'")
                    let js = "showToast('✅ 导出成功，已保存至: \(safeName)');"
                    DispatchQueue.main.async {
                        self?.webView.evaluateJavaScript(js, completionHandler: nil)
                    }
                } catch {
                    print("写入 SVG 文件失败: \(error)")
                }
            }
        }
    }

    // 核心：加载指定文件并开启热重载监听
    func openFile(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        currentFilePath = path
        let filename = (path as NSString).lastPathComponent
        if let win = window {
            win.title = "\(filename) - Markdown 视觉预览器"
        }

        guard isWebViewReady else {
            pendingFilePath = path
            return
        }

        loadFileContent(path: path)
        watchFile(path: path)
    }

    func loadFileContent(path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let filename = (path as NSString).lastPathComponent

            let jsonObj: [String: String] = ["content": content, "filename": filename]
            if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObj, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let js = "window.updateMarkdown(JSON.parse(\(quoteString(jsonString))).content, JSON.parse(\(quoteString(jsonString))).filename);"
                DispatchQueue.main.async {
                    self.webView.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        } catch {
            print("读取文件失败: \(error)")
        }
    }

    func quoteString(_ s: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [s], options: []),
              let str = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return str.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    }

    // 原生文件监听：使用 GCD DispatchSource 监听修改事件
    func watchFile(path: String) {
        fileSource?.cancel()
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            guard let self = self, let p = self.currentFilePath else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                // 如果文件被原子重写，稍微延时重新绑定监听
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.watchFile(path: p)
                    self.loadFileContent(path: p)
                }
            } else {
                self.loadFileContent(path: p)
            }
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        fileSource = source
        source.resume()
    }

    // 菜单响应
    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []

        if panel.runModal() == .OK, let url = panel.url {
            openFile(path: url.path)
        }
    }

    @objc func reloadCurrentFile(_ sender: Any?) {
        if let p = currentFilePath {
            loadFileContent(path: p)
        }
    }

    @objc func zoomIn(_ sender: Any?) {
        webView.pageZoom += 0.15
    }

    @objc func zoomOut(_ sender: Any?) {
        webView.pageZoom = max(0.4, webView.pageZoom - 0.15)
    }

    @objc func resetZoom(_ sender: Any?) {
        webView.pageZoom = 1.0
    }

    @objc func toggleFullWidth(_ sender: Any?) {
        webView.evaluateJavaScript("toggleFullWidth();", completionHandler: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// 支持拖拽文件至窗口
extension AppDelegate {
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? [String],
              let first = pasteboard.first else {
            return false
        }
        openFile(path: first)
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
