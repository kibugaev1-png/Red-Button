// main.swift — нативное окно macOS с игрой внутри WKWebView.
// Никакого браузера: своё окно, свой значок в доке, полноэкранный режим.
import Cocoa
import WebKit

let GAME_DIR = ProcessInfo.processInfo.environment["GAME_DIR"] ?? "@@GAME_DIR@@"

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
  var window: NSWindow!
  var web: WKWebView!

  func applicationDidFinishLaunching(_ n: Notification) {
    let cfg = WKWebViewConfiguration()
    cfg.preferences.setValue(true, forKey: "developerExtrasEnabled")
    // локальные файлы игры должны читаться из папки проекта
    cfg.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
    cfg.defaultWebpagePreferences.allowsContentJavaScript = true

    let rect = NSRect(x: 0, y: 0, width: 1280, height: 760)
    web = WKWebView(frame: rect, configuration: cfg)
    web.navigationDelegate = self
    web.allowsMagnification = false

    window = NSWindow(
      contentRect: rect,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "Красная кнопка"
    window.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.07, alpha: 1)
    window.contentView = web
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.collectionBehavior = [.fullScreenPrimary]

    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    buildMenu()
    load()
  }

  func load() {
    // сначала папка с исходниками — правки в коде видно сразу после перезапуска,
    // если её нет, берём копию внутри самого приложения
    var dir = URL(fileURLWithPath: GAME_DIR, isDirectory: true)
    var index = dir.appendingPathComponent("index.html")
    if !FileManager.default.fileExists(atPath: index.path),
       let res = Bundle.main.resourceURL?.appendingPathComponent("game") {
      dir = res
      index = dir.appendingPathComponent("index.html")
    }
    if FileManager.default.fileExists(atPath: index.path) {
      web.loadFileURL(index, allowingReadAccessTo: dir)
    } else {
      web.loadHTMLString("<body style='background:#15161a;color:#d8d2c2;font:16px system-ui;padding:40px'>" +
        "Не нашёл файлы игры.<br>Ожидал: \(index.path)</body>", baseURL: nil)
    }
  }

  func buildMenu() {
    let main = NSMenu()
    let appItem = NSMenuItem()
    main.addItem(appItem)
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Перезапустить игру", action: #selector(reload), keyEquivalent: "r")
    appMenu.addItem(withTitle: "Во весь экран", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu
    NSApp.mainMenu = main
  }

  @objc func reload() { load() }

  func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
