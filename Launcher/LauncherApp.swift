import SwiftUI
import AppKit
import Carbon
import CoreServices

@main
struct LauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var hotKeyRef: EventHotKeyRef?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Register global hotkey (Cmd+Space)
        registerGlobalHotkey()
        
        // Create window
        createWindow()
        
        // Always show the window when app becomes active to keep launcher on top
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Show window immediately after launch (restored original behavior)
        showLauncher()
    }
    
    @objc func applicationDidBecomeActive(_ notification: Notification) {
        // Focus the search field when the app becomes active
        // This ensures the search field is ready for input when the launcher is shown
    }
    
    func registerGlobalHotkey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C4E4348), id: 1) // 'LNCH'
        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(cmdKey)
        
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status == noErr {
            self.hotKeyRef = hotKeyRef
            
            // Install event handler with safer memory management
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
            let selfPtr = Unmanaged.passRetained(self).toOpaque()
            
            InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    appDelegate.toggleLauncher()
                }
                return noErr
            }, 1, &eventType, selfPtr, nil)
        }
    }
    
    func createWindow() {
        let isUITest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let style: NSWindow.StyleMask = isUITest ? [.titled, .closable, .fullSizeContentView] : [.borderless, .fullSizeContentView]
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 60),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        
        window?.title = "Launcher"
        window?.center()
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.hasShadow = true
        
        // Make window focusable and key-able
        window?.canHide = false
        window?.isReleasedWhenClosed = false
        window?.hidesOnDeactivate = false
        
        // Create a custom window to override canBecomeKey
        if let currentWindow = window {
            let customWindow = FocusableWindow(
                contentRect: currentWindow.frame,
                styleMask: currentWindow.styleMask,
                backing: currentWindow.backingType,
                defer: false
            )
            
            customWindow.title = "Launcher"
            customWindow.center()
            customWindow.isOpaque = false
            customWindow.backgroundColor = .clear
            customWindow.hasShadow = true
            customWindow.canHide = false
            customWindow.isReleasedWhenClosed = false
            customWindow.hidesOnDeactivate = false
            customWindow.level = .floating
            
            customWindow.contentView = NSHostingView(rootView: LauncherView(
                onClose: { self.hideLauncher() },
                onSizeChange: { newSize in
                    self.animateWindowResize(to: newSize)
                }
            ))
            
            window = customWindow
        }
        
        if isUITest {
            print("[DEBUG] UI Test Mode: Using standard window style for accessibility.")
        }
    }
    
    func animateWindowResize(to newSize: CGSize) {
        guard let window = window else { return }
        
        let currentFrame = window.frame
        let newFrame = NSRect(
            x: currentFrame.midX - newSize.width / 2,
            y: currentFrame.origin.y + currentFrame.height - newSize.height,
            width: newSize.width,
            height: newSize.height
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }
    
    func toggleLauncher() {
        guard let window = window else { return }
        
        if window.isVisible {
            hideLauncher()
        } else {
            showLauncher()
        }
    }
    
    func showLauncher() {
        guard let window = window else { return }
        
        // Always center window on screen consistently
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let windowFrame = window.frame
            let x = (screenFrame.width - windowFrame.width) / 2
            let y = (screenFrame.height - windowFrame.height) / 2 // Center vertically
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideLauncher() {
        window?.orderOut(nil)
    }
}

struct LauncherView: View {
    @State private var searchText = ""
    @State private var applications: [AppInfo] = []
    @State private var filteredApps: [AppInfo] = []
    @State private var selectedIndex = 0
    @State private var isExpanded = false
    @FocusState private var isSearchFieldFocused: Bool
    let onClose: () -> Void
    let onSizeChange: (CGSize) -> Void
    
    private let compactHeight: CGFloat = 60
    private let expandedHeight: CGFloat = 400
    private let windowWidth: CGFloat = 600
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                TextField("Search applications...", text: $searchText)
                    .focused($isSearchFieldFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 18))
                    .onSubmit {
                        if !filteredApps.isEmpty {
                            launchSelectedApp()
                        }
                    }
                    .onChange(of: searchText) {
                        filterApplications()
                        updateWindowSize()
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // App list - only show when expanded
            if isExpanded {
                Divider()
                    .opacity(0.3)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(filteredApps.enumerated()), id: \.element.id) { index, app in
                                AppRowView(
                                    app: app,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    selectedIndex = index
                                    launchSelectedApp()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: selectedIndex) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(selectedIndex, anchor: .center)
                        }
                    }
                }
                .frame(height: expandedHeight - compactHeight - 1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: windowWidth)
        .background(
            VisualEffectView()
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            loadApplications()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            focusSearchField()
        }
        .onKeyPress(.upArrow) {
            if isExpanded && selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if isExpanded && selectedIndex < filteredApps.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            if !filteredApps.isEmpty {
                launchSelectedApp()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }
    
    private func updateWindowSize() {
        let shouldExpand = !searchText.isEmpty
        
        if shouldExpand != isExpanded {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = shouldExpand
            }
            
            let newSize = CGSize(
                width: windowWidth,
                height: shouldExpand ? expandedHeight : compactHeight
            )
            onSizeChange(newSize)
        }
    }
    
    private func focusSearchField() {
        DispatchQueue.main.async {
            isSearchFieldFocused = true
        }
    }
    
    private func loadApplications() {
        applications = ApplicationLoader.loadApplications()
        filterApplications()
    }
    
    private func filterApplications() {
        filteredApps = ApplicationLoader.filterApplications(applications, searchText: searchText)
        
        print("[DEBUG] Search text: '", searchText, "' => Filtered: [", filteredApps.map { $0.name }.joined(separator: ", "), "]")
        print("[DEBUG] Selected index: \(selectedIndex), First result: \(filteredApps.first?.name ?? "none")")
        selectedIndex = 0
    }
    
    private func launchSelectedApp() {
        guard selectedIndex < filteredApps.count else { return }
        
        let app = filteredApps[selectedIndex]
        let url = URL(fileURLWithPath: app.path)
        
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                print("Error launching app: \(error)")
            }
        }
        
        // Reset state when closing
        searchText = ""
        selectedIndex = 0
        isExpanded = false
        onClose()
    }
}

struct AppRowView: View {
    let app: AppInfo
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            Text(app.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .padding(.horizontal, 8)
    }
}

// Visual Effect View for native macOS blur
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // The view automatically adapts to light/dark mode
    }
}

// Custom window class that can become key window
class FocusableWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

struct AppInfo: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let icon: NSImage
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.name == rhs.name && lhs.path == rhs.path
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(path)
    }
}

// MARK: - Application Loading Logic (Extracted for Testing)

class ApplicationLoader {
    static func loadApplications() -> [AppInfo] {
        var allApps: [AppInfo] = []
        
        // Get applications from common directories
        let appDirectories = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]
        
        for directory in appDirectories {
            if let enumerator = FileManager.default.enumerator(atPath: directory) {
                while let file = enumerator.nextObject() as? String {
                    if file.hasSuffix(".app") {
                        let fullPath = directory + "/" + file
                        let name = file.replacingOccurrences(of: ".app", with: "")
                        let icon = NSWorkspace.shared.icon(forFile: fullPath)
                        
                        let appInfo = AppInfo(
                            name: name,
                            path: fullPath,
                            icon: icon
                        )
                        
                        allApps.append(appInfo)
                    }
                }
            }
        }
        
        // Remove duplicates and sort alphabetically for consistent display
        let finalApps = Array(Set(allApps)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        print("[DEBUG] Final app count after deduplication: \(finalApps.count)")
        return finalApps
    }
    
    static func filterApplications(_ applications: [AppInfo], searchText: String) -> [AppInfo] {
        if searchText.isEmpty {
            return applications
        } else {
            let lowercasedSearchText = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Only use prefix matching - no substring matching
            let prefixMatches = applications.filter { app in
                let lowercasedAppName = app.name.lowercased()
                return lowercasedAppName.hasPrefix(lowercasedSearchText)
            }
            // Sort prefix matches alphabetically
            return prefixMatches.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

// MARK: - App Delegate
