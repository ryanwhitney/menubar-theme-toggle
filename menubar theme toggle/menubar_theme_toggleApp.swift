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
        NSApp.setActivationPolicy(.accessory)
        print("App hidden from dock")
        

        requestAccessibilityPermissions()
        
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            updateButtonTitle()
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Toggle theme"
            button.setAccessibilityLabel("Toggle theme")
        }
        
        // Listen for system theme changes
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(systemThemeChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    func requestAccessibilityPermissions() {
        if hasRequestedPermissions {
            return
        }
        
        let accessEnabled = AXIsProcessTrusted()
        
        if accessEnabled {
            print("Accessibility access granted")
            hasRequestedPermissions = true
        } else {
            let hasShownDialog = UserDefaults.standard.bool(forKey: "HasShownAccessibilityDialog")
            
            if !hasShownDialog {
                print("Requesting accessibility permissions...")
                
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
                let _ = AXIsProcessTrustedWithOptions(options)
                
                UserDefaults.standard.set(true, forKey: "HasShownAccessibilityDialog")
                hasRequestedPermissions = true
                
                print("Permission dialog shown")
            } else {
                print("Accessibility permissions needed in System Preferences")
                hasRequestedPermissions = true
            }
        }
    }
    
    @objc func handleClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleTheme()
        }
    }
    
    func toggleTheme() {
        print("Toggling theme from \(themeManager.currentMode)")
        themeManager.toggleTheme()
        updateButtonTitle()
    }
    
    func showContextMenu() {
        let menu = NSMenu()
        
        // Run on Startup option
        let startupItem = NSMenuItem(title: "Run on login", action: #selector(toggleStartup), keyEquivalent: "")
        startupItem.target = self
        startupItem.state = isInLoginItems() ? .on : .off
        menu.addItem(startupItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit option
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        if let button = statusBarItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }
    
    @objc func toggleStartup() {
        if isInLoginItems() {
            removeFromLoginItems()
        } else {
            addToLoginItems()
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func systemThemeChanged() {
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
                print("Added to login items")
            } catch {
                print("Failed to add to login items: \(error)")
            }
        } else {
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                print("Could not get bundle identifier")
                return
            }
            
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, true) {
                UserDefaults.standard.set(true, forKey: "LaunchAtLogin_\(bundleIdentifier)")
                print("Added to login items")
            } else {
                print("Failed to add to login items")
            }
        }
    }
    
    func removeFromLoginItems() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
                print("Removed from login items")
            } catch {
                print("Failed to remove from login items: \(error)")
            }
        } else {
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                print("Could not get bundle identifier")
                return
            }
            
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, false) {
                UserDefaults.standard.set(false, forKey: "LaunchAtLogin_\(bundleIdentifier)")
                print("Removed from login items")
            } else {
                print("Failed to remove from login items")
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
}

class ThemeManager: ObservableObject {
    @Published var currentMode: ThemeMode
    private var isUpdatingFromSystem = false
    
    init() {
        self.currentMode = ThemeManager.readCurrentSystemTheme()
    }
    
    func toggleTheme() {
        print("Toggling from \(currentMode)")
        
        switch currentMode {
        case .dark:
            setMode(.light)
        case .light:
            setMode(.dark)
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
        currentMode = mode
        if !isUpdatingFromSystem {
            applyTheme()
        }
    }
    
    private static func readCurrentSystemTheme() -> ThemeMode {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "-g", "AppleInterfaceStyle"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if output == "Dark" {
                return .dark
            } else {
                return .light
            }
        } catch {
            return .light
        }
    }
    
    private func applyTheme() {
        print("Applying \(currentMode) theme")
        DispatchQueue.main.async {
            switch self.currentMode {
            case .dark:
                self.setSystemAppearance(dark: true)
            case .light:
                self.setSystemAppearance(dark: false)
            }
        }
    }
    
    private func setSystemAppearance(dark: Bool) {
        if dark {
            runShellCommand("osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to true'")
        } else {
            runShellCommand("osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to false'")
        }
        
        DistributedNotificationCenter.default.post(
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    private func runShellCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                print("Command failed: \(command), error: \(output)")
            }
        } catch {
            print("Failed to run command: \(command), error: \(error)")
        }
    }
}
