import AppKit
import Swifter
import Foundation
import SwiftUI
import QuartzCore // For CABasicAnimation

// MARK: - Models

enum IAStatus: String, Codable {
    case idle
    case working
    case waiting
}

struct StatusPayload: Codable {
    let id: String
    let name: String
    let status: IAStatus
}

struct AskPayload: Codable {
    let id: String
    let question: String
    let options: [String]
}

struct AskResponse: Codable {
    let selectedOption: String
}

// MARK: - Icon View for Animations
class IconView: NSView {
    var letter: String = "C" {
        didSet { needsDisplay = true }
    }
    var color: NSColor = .systemGreen {
        didSet { needsDisplay = true }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Pass clicks through to the status item button
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Dimensions for the squircle
        let size: CGFloat = 18.0
        let rect = NSRect(x: (bounds.width - size) / 2.0,
                          y: (bounds.height - size) / 2.0,
                          width: size, height: size)
        
        let path = NSBezierPath(roundedRect: rect, xRadius: 4.5, yRadius: 4.5)
        
        // Create a beautiful gradient based on the status color
        let startColor: NSColor
        let endColor: NSColor
        
        if color == .systemGreen {
            startColor = NSColor(calibratedRed: 0.3, green: 0.85, blue: 0.4, alpha: 1.0)
            endColor = NSColor(calibratedRed: 0.1, green: 0.65, blue: 0.2, alpha: 1.0)
        } else if color == .systemOrange {
            startColor = NSColor(calibratedRed: 1.0, green: 0.65, blue: 0.1, alpha: 1.0)
            endColor = NSColor(calibratedRed: 0.9, green: 0.45, blue: 0.0, alpha: 1.0)
        } else { // Red
            startColor = NSColor(calibratedRed: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
            endColor = NSColor(calibratedRed: 0.8, green: 0.1, blue: 0.15, alpha: 1.0)
        }
        
        let gradient = NSGradient(starting: startColor, ending: endColor)
        gradient?.draw(in: path, angle: -90)
        
        // Optional subtle border
        NSColor.black.withAlphaComponent(0.15).setStroke()
        path.lineWidth = 0.5
        path.stroke()
        
        // Draw the crisp white letter
        let text = letter.prefix(1).uppercased()
        let font = NSFont.systemFont(ofSize: 13, weight: .bold)
        
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 1.0
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .shadow: shadow
        ]
        
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()
        
        let textRect = NSRect(
            x: rect.origin.x + (rect.width - textSize.width) / 2.0,
            y: rect.origin.y + (rect.height - textSize.height) / 2.0,
            width: textSize.width,
            height: textSize.height
        )
        string.draw(in: textRect)
    }
    
    func startPulsing() {
        guard let layer = self.layer else { return }
        layer.removeAllAnimations()
        
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.25
        animation.duration = 0.85
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(animation, forKey: "pulsing")
    }
    
    func stopPulsing() {
        self.layer?.removeAllAnimations()
        self.layer?.opacity = 1.0
    }
}

// MARK: - IA Context

class IAContext {
    var id: String
    var name: String
    var status: IAStatus = .idle
    var iconView: IconView?
    var selectedOption: String?
    var currentSemaphore: DispatchSemaphore?
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - SwiftUI View for Menu

struct InteractiveAskView: View {
    let payload: AskPayload
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text(payload.question)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)
            
            VStack(spacing: 10) {
                ForEach(payload.options, id: \.self) { option in
                    Button(action: {
                        onSelect(option)
                    }) {
                        Text(option)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.85))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

// MARK: - Main Application Controller

class AppDelegate: NSObject, NSApplicationDelegate {
    let server = HttpServer()
    var contexts: [String: IAContext] = [:]
    var activeIDs: [String] = []
    var mainStatusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        mainStatusItem = NSStatusBar.system.statusItem(withLength: 26)
        if let button = mainStatusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        setupServer()
        
        // Create a default icon so the user knows the app is running
        _ = getContext(id: "main", name: "IA")
        
        do {
            try server.start(50152, forceIPv4: true)
            print("Server has started on port 50152")
        } catch {
            print("Server start error: \(error)")
        }
    }
    
    func setupServer() {
        server["/status"] = { [weak self] request in
            guard let self = self else { return .internalServerError }
            let data = Data(request.body)
            do {
                let payload = try JSONDecoder().decode(StatusPayload.self, from: data)
                self.updateStatus(payload: payload)
                return .ok(.text("Status updated"))
            } catch {
                return .badRequest(.text("Invalid JSON"))
            }
        }
        
        server["/ask"] = { [weak self] request in
            guard let self = self else { return .internalServerError }
            let data = Data(request.body)
            do {
                let payload = try JSONDecoder().decode(AskPayload.self, from: data)
                return self.handleAsk(payload: payload)
            } catch {
                return .badRequest(.text("Invalid JSON"))
            }
        }
        
        // Remove an IA from the menu bar
        server["/remove"] = { [weak self] request in
            guard let self = self else { return .internalServerError }
            if let id = request.queryParams.first(where: { $0.0 == "id" })?.1 {
                self.removeIA(id: id)
            }
            return .ok(.text("Removed"))
        }
    }
    
    // MARK: - UI Updates (Must be on Main Thread)
    
    func updateStatus(payload: StatusPayload) {
        DispatchQueue.main.async {
            let context = self.getContext(id: payload.id, name: payload.name)
            context.name = payload.name
            context.status = payload.status
            self.refreshStatusItem(for: context)
        }
    }
    
    func removeIA(id: String) {
        DispatchQueue.main.async {
            if self.contexts[id] != nil {
                self.contexts.removeValue(forKey: id)
                self.activeIDs.removeAll { $0 == id }
                self.rebuildIcons()
            }
        }
    }
    
    func handleAsk(payload: AskPayload) -> HttpResponse {
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            let context = self.getContext(id: payload.id, name: payload.id.capitalized)
            context.status = .waiting
            context.currentSemaphore = semaphore
            context.selectedOption = nil
            
            self.refreshStatusItem(for: context)
            
            let menu = NSMenu()
            let menuItem = NSMenuItem()
            
            let hostView = NSHostingView(rootView: InteractiveAskView(payload: payload, onSelect: { [weak self] selectedOption in
                menu.cancelTracking()
                
                guard let self = self, let ctx = self.contexts[payload.id] else { return }
                ctx.selectedOption = selectedOption
                ctx.currentSemaphore?.signal()
            }))
            
            let size = hostView.fittingSize
            hostView.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
            
            menuItem.view = hostView
            menu.addItem(menuItem)
            
            self.mainStatusItem.menu = menu
        }
        
        // Block until user clicks an option
        _ = semaphore.wait(timeout: .distantFuture)
        
        var responseText = ""
        DispatchQueue.main.sync {
            let context = self.contexts[payload.id]
            responseText = context?.selectedOption ?? ""
            // Clear menu after selection
            self.mainStatusItem.menu = nil
            context?.status = .working
            if let ctx = context {
                self.refreshStatusItem(for: ctx)
            }
        }
        
        let response = AskResponse(selectedOption: responseText)
        if let responseData = try? JSONEncoder().encode(response) {
            return .raw(200, "OK", ["Content-Type": "application/json"]) { writer in
                try? writer.write(responseData)
            }
        }
        
        return .internalServerError
    }
    
    func getContext(id: String, name: String) -> IAContext {
        if id != "main" {
            removeIA(id: "main")
        }
        
        if let existing = contexts[id] {
            return existing
        }
        
        let newContext = IAContext(id: id, name: name)
        contexts[id] = newContext
        activeIDs.append(id)
        
        rebuildIcons()
        
        return newContext
    }
    
    func rebuildIcons() {
        guard let button = mainStatusItem.button else { return }
        
        button.subviews.forEach { $0.removeFromSuperview() }
        
        let newLength = CGFloat(max(1, activeIDs.count) * 26)
        mainStatusItem.length = newLength
        
        for (index, id) in activeIDs.enumerated() {
            guard let context = contexts[id] else { continue }
            
            let rect = NSRect(x: CGFloat(index * 26), y: 0, width: 26, height: button.bounds.height > 0 ? button.bounds.height : 22)
            let iconView = IconView(frame: rect)
            iconView.autoresizingMask = [.height]
            
            button.addSubview(iconView)
            context.iconView = iconView
            
            refreshStatusItem(for: context)
        }
    }
    
    func refreshStatusItem(for context: IAContext) {
        let color: NSColor
        switch context.status {
        case .idle: color = .systemGreen
        case .working: color = .systemOrange
        case .waiting: color = .systemRed
        }
        
        if let iconView = context.iconView {
            iconView.letter = context.name
            iconView.color = color
            
            if context.status == .working {
                iconView.startPulsing()
            } else {
                iconView.stopPulsing()
            }
        }
    }
    
    func logDebug(_ message: String) {
        // ... (keep this intact for future debugging, or remove if not needed. Let's keep it simple)
        let path = "/tmp/iacompanion.log"
        let text = "\(Date()): \(message)\n"
        if let data = text.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: path) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        // Find which icon was clicked based on X coordinate
        let location = sender.convert(event.locationInWindow, from: nil)
        let index = Int(location.x / 26.0)
        
        guard index >= 0 && index < activeIDs.count else { return }
        let id = activeIDs[index]
        
        if id.lowercased() == "claude" {
            bringAppToFront(names: ["Claude", "iTerm", "Terminal", "iTerm2", "Ghostty", "Visual Studio Code", "Code"])
        } else {
            bringAppToFront(names: ["iTerm", "Terminal", "iTerm2", "Ghostty", "Visual Studio Code", "Code"])
        }
    }
    
    func bringAppToFront(names: [String]) {
        logDebug("bringAppToFront: Looking for \(names)")
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        // Debug: log all running apps
        for app in runningApps {
            if let name = app.localizedName {
                if names.contains(name) {
                    logDebug("bringAppToFront: Found match = \(name) (Bundle: \(app.bundleIdentifier ?? ""))")
                }
            }
        }
        
        for name in names {
            if let app = runningApps.first(where: { $0.localizedName == name }) {
                logDebug("bringAppToFront: Activating \(name)")
                app.activate(options: .activateIgnoringOtherApps)
                
                // If the app is Terminal/iTerm, it might need to be unhidden
                if app.isHidden {
                    app.unhide()
                }
                return
            }
        }
        logDebug("bringAppToFront: No matching app found.")
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
