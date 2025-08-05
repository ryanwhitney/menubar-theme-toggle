//
//  menubar_theme_toggleApp.swift
//  menubar theme toggle
//
//  Created by Ryan Whitney on 8/5/25.
//

import SwiftUI
import Cocoa
import ServiceManagement

extension UserDefaults {
    func objectExists(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

@main
struct menubar_theme_toggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var themeManager = ThemeManager()
    private var hasRequestedPermissions = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the app from the dock
        NSApp.setActivationPolicy(.accessory)
        print("✅ App set to accessory mode - dock icon should be hidden")
        
        // Initialize ShowAuto preference if not set
        if !UserDefaults.standard.objectExists(forKey: "ShowAuto") {
            UserDefaults.standard.set(true, forKey: "ShowAuto")
        }
        
        // Initialize theme manager with the Show Auto preference
        themeManager.showAuto = UserDefaults.standard.bool(forKey: "ShowAuto")
        
        // Request accessibility permissions
        requestAccessibilityPermissions()
        
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            updateButtonTitle()
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create the context menu
        createContextMenu()
        
        // Listen for system theme changes to stay in sync
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(systemThemeChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    func requestAccessibilityPermissions() {
        // Check if we've already asked during this session
        if hasRequestedPermissions {
            print("🔄 Permissions already checked this session")
            return
        }
        
        // Check if we already have accessibility permissions
        let accessEnabled = AXIsProcessTrusted()
        
        if accessEnabled {
            print("✅ Accessibility access already granted")
            hasRequestedPermissions = true
        } else {
            // Check if we've shown the dialog before by checking UserDefaults
            let hasShownDialog = UserDefaults.standard.bool(forKey: "HasShownAccessibilityDialog")
            
            if !hasShownDialog {
                print("⚠️ Accessibility access required for system appearance changes")
                print("🔍 Showing accessibility permission prompt...")
                
                // Show the prompt
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
                let _ = AXIsProcessTrustedWithOptions(options)
                
                // Mark that we've shown the dialog
                UserDefaults.standard.set(true, forKey: "HasShownAccessibilityDialog")
                hasRequestedPermissions = true
                
                print("📝 Permission dialog shown - user needs to grant access in System Preferences")
            } else {
                print("⚠️ Accessibility permissions not granted (user needs to enable in System Preferences)")
                hasRequestedPermissions = true
            }
        }
    }
    
    @objc func handleClick() {
        // Check which mouse button was clicked
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            // Right click - show context menu
            showContextMenu()
        } else {
            // Left click - toggle theme
            toggleTheme()
        }
    }
    
    func toggleTheme() {
        print("🔄 Toggle button clicked - current mode: \(themeManager.currentMode)")
        themeManager.toggleTheme()
        updateButtonTitle()
        print("✅ Toggle completed - new mode: \(themeManager.currentMode)")
    }
    
    func createContextMenu() {
        let menu = NSMenu()
        
        // Show Auto option
        let showAutoItem = NSMenuItem(title: "Show Auto", action: #selector(toggleShowAuto), keyEquivalent: "")
        showAutoItem.target = self
        showAutoItem.state = UserDefaults.standard.bool(forKey: "ShowAuto") ? .on : .off
        menu.addItem(showAutoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Run on Startup option
        let startupItem = NSMenuItem(title: "Run on Startup", action: #selector(toggleStartup), keyEquivalent: "")
        startupItem.target = self
        startupItem.state = self.isInLoginItems() ? .on : .off
        menu.addItem(startupItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit option
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Don't assign menu to statusBarItem - we'll show it manually on right-click
    }
    
    func showContextMenu() {
        // Create the menu fresh each time to ensure updated states
        let menu = NSMenu()
        
        // Show Auto option
        let showAutoItem = NSMenuItem(title: "Show Auto", action: #selector(toggleShowAuto), keyEquivalent: "")
        showAutoItem.target = self
        showAutoItem.state = UserDefaults.standard.bool(forKey: "ShowAuto") ? .on : .off
        menu.addItem(showAutoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Run on Startup option
        let startupItem = NSMenuItem(title: "Run on Startup", action: #selector(toggleStartup), keyEquivalent: "")
        startupItem.target = self
        startupItem.state = self.isInLoginItems() ? .on : .off
        menu.addItem(startupItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit option
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Show the menu at the status bar item location
        if let button = statusBarItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }
    
    @objc func toggleShowAuto() {
        let currentValue = UserDefaults.standard.bool(forKey: "ShowAuto")
        UserDefaults.standard.set(!currentValue, forKey: "ShowAuto")
        
        // Update the theme manager to include/exclude auto mode
        themeManager.showAuto = !currentValue
        
        print("Show Auto toggled to: \(!currentValue)")
    }
    
    @objc func toggleStartup() {
        if self.isInLoginItems() {
            self.removeFromLoginItems()
        } else {
            self.addToLoginItems()
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func systemThemeChanged() {
        // Re-read the system preference to stay in sync
        DispatchQueue.main.async {
            self.themeManager.refreshFromSystem()
            self.updateButtonTitle()
        }
    }
    
    func updateButtonTitle() {
        guard let button = statusBarItem.button else { return }
        
        switch themeManager.currentMode {
        case .dark:
            button.title = "D"
        case .light:
            button.title = "L"
        case .auto:
            button.title = "A"
        }
    }
    
    // MARK: - Login Items Management
    func isInLoginItems() -> Bool {
        // Check if the app is registered as a login item
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // Fallback for older macOS versions
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
            return UserDefaults.standard.bool(forKey: "LaunchAtLogin_\(bundleIdentifier)")
        }
    }
    
    func addToLoginItems() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                print("✅ Added to login items")
            } catch {
                print("❌ Failed to add to login items: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                print("❌ Could not get bundle identifier")
                return
            }
            
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, true) {
                UserDefaults.standard.set(true, forKey: "LaunchAtLogin_\(bundleIdentifier)")
                print("✅ Added to login items")
            } else {
                print("❌ Failed to add to login items")
            }
        }
    }
    
    func removeFromLoginItems() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
                print("✅ Removed from login items")
            } catch {
                print("❌ Failed to remove from login items: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                print("❌ Could not get bundle identifier")
                return
            }
            
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, false) {
                UserDefaults.standard.set(false, forKey: "LaunchAtLogin_\(bundleIdentifier)")
                print("✅ Removed from login items")
            } else {
                print("❌ Failed to remove from login items")
            }
        }
    }
    
    deinit {
        DistributedNotificationCenter.default.removeObserver(self)
    }
}

enum ThemeMode: String, CaseIterable {
    case dark = "Dark"
    case light = "Light"
    case auto = "System"
}

class ThemeManager: ObservableObject {
    @Published var currentMode: ThemeMode
    private var isUpdatingFromSystem = false
    var showAuto: Bool = true {
        didSet {
            UserDefaults.standard.set(showAuto, forKey: "ShowAuto")
        }
    }
    
    init() {
        self.currentMode = ThemeManager.readCurrentSystemTheme()
        
        // Initialize showAuto from UserDefaults, default to true if not set
        if UserDefaults.standard.object(forKey: "ShowAuto") != nil {
            self.showAuto = UserDefaults.standard.bool(forKey: "ShowAuto")
        } else {
            self.showAuto = true
            UserDefaults.standard.set(true, forKey: "ShowAuto")
        }
        
        // If ShowAuto is false and we're currently in auto mode, switch to dark mode
        if !showAuto && currentMode == .auto {
            currentMode = .dark
        }
        
        // Don't apply theme on init since we're reading the current system state
    }
    
    func toggleTheme() {
        print("📱 ThemeManager.toggleTheme() called - current: \(currentMode), showAuto: \(showAuto)")
        
        if showAuto {
            // Full cycle: Dark → Light → Auto → Dark
            switch currentMode {
            case .dark:
                print("  → Switching from Dark to Light")
                setMode(.light)
            case .light:
                print("  → Switching from Light to Auto")
                setMode(.auto)
            case .auto:
                print("  → Switching from Auto to Dark")
                setMode(.dark)
            }
        } else {
            // Simple cycle: Dark ↔ Light
            switch currentMode {
            case .dark:
                print("  → Switching from Dark to Light")
                setMode(.light)
            case .light, .auto:
                print("  → Switching from Light to Dark")
                setMode(.dark)
            }
        }
    }
    
    func refreshFromSystem() {
        let newMode = ThemeManager.readCurrentSystemTheme()
        if newMode != currentMode {
            isUpdatingFromSystem = true
            currentMode = newMode
            isUpdatingFromSystem = false
        }
    }
    
    private func setMode(_ mode: ThemeMode) {
        print("🎯 setMode called with: \(mode), isUpdatingFromSystem: \(isUpdatingFromSystem)")
        currentMode = mode
        if !isUpdatingFromSystem {
            print("  → Applying theme...")
            applyTheme()
        } else {
            print("  → Skipping applyTheme (updating from system)")
        }
    }
    
    private static func readCurrentSystemTheme() -> ThemeMode {
        // Read the system appearance preference
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "-g", "AppleInterfaceStyle"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Capture errors to avoid output
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if output == "Dark" {
                return .dark
            } else if output.isEmpty {
                // When light mode is set, the key doesn't exist, so we get empty output
                return .light
            }
        } catch {
            // If we can't read the preference, check if auto mode is set
            return ThemeManager.checkIfAutoMode() ? .auto : .light
        }
        
        return ThemeManager.checkIfAutoMode() ? .auto : .light
    }
    
    private static func checkIfAutoMode() -> Bool {
        // Check if the system is set to auto mode by looking for the auto switch preference
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "-g", "AppleInterfaceStyleSwitchesAutomatically"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            return output == "1"
        } catch {
            return false
        }
    }
    
    private func applyTheme() {
        print("🎨 applyTheme called for mode: \(currentMode)")
        DispatchQueue.main.async {
            switch self.currentMode {
            case .dark:
                print("  → Setting system to Dark mode")
                self.setSystemAppearance(dark: true, auto: false)
            case .light:
                print("  → Setting system to Light mode")
                self.setSystemAppearance(dark: false, auto: false)
            case .auto:
                print("  → Setting system to Auto mode")
                self.setSystemAppearance(dark: false, auto: true)
            }
        }
    }
    
    private func setSystemAppearance(dark: Bool, auto: Bool) {
        print("⚙️ setSystemAppearance called - dark: \(dark), auto: \(auto)")
        
        // Use hybrid approach: AppleScript for dark/light, defaults for auto
        if auto {
            print("  🔄 Setting auto mode...")
            // Use defaults for auto mode since AppleScript automatic property doesn't work
            runShellCommand("defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool true")
            runShellCommand("defaults delete -g AppleInterfaceStyle")
        } else if dark {
            print("  🌙 Setting dark mode...")
            runShellCommand("osascript -e 'tell application \"System Events\" to tell appearance preferences to set automatic to false'")
            runShellCommand("osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to true'")
        } else {
            print("  ☀️ Setting light mode...")
            runShellCommand("osascript -e 'tell application \"System Events\" to tell appearance preferences to set automatic to false'")
            runShellCommand("osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to false'")
        }
        
        print("  📢 Posting notification...")
        // Notify all applications of the change
        DistributedNotificationCenter.default.post(
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        print("  ✅ Notification posted")
    }
    
    private func runShellCommand(_ command: String) {
        print("    💻 Running: \(command)")
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if task.terminationStatus == 0 {
                print("    ✅ Command succeeded")
                if !output.isEmpty {
                    print("    📄 Output: \(output)")
                }
            } else {
                print("    ❌ Command failed (exit code: \(task.terminationStatus))")
                if !output.isEmpty {
                    print("    📄 Error: \(output)")
                }
            }
        } catch {
            print("    ❌ Failed to run command: \(error)")
        }
    }
    
    private func runAppleScript(_ script: String) {
        print("    🍎 Running AppleScript: \(script)")
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if task.terminationStatus == 0 {
                print("    ✅ AppleScript succeeded (exit code: \(task.terminationStatus))")
                if !output.isEmpty {
                    print("    📄 Output: \(output)")
                }
            } else {
                print("    ❌ AppleScript failed (exit code: \(task.terminationStatus))")
                if !output.isEmpty {
                    print("    📄 Error output: \(output)")
                }
            }
        } catch {
            print("    ❌ Failed to run AppleScript: \(error)")
        }
    }
}
