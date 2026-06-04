//
//  AlwaysWithApp.swift
//  AlwaysWith
//
//  Created by Francesco Face on 04/06/26.
//

import SwiftUI
import AppKit
import CoreText

extension Notification.Name {
    static let listNavUp       = Notification.Name("AlwaysWith.listNavUp")
    static let listNavDown     = Notification.Name("AlwaysWith.listNavDown")
    static let listNavPageUp   = Notification.Name("AlwaysWith.listNavPageUp")
    static let listNavPageDown = Notification.Name("AlwaysWith.listNavPageDown")
    static let listNavHome     = Notification.Name("AlwaysWith.listNavHome")
    static let listNavEnd      = Notification.Name("AlwaysWith.listNavEnd")
}

@main
struct AlwaysWithApp: App {
    init() {
        if let url = Bundle.main.url(forResource: "Nunito", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        NSWindow.allowsAutomaticWindowTabbing = false
        installFindShortcutMonitor()
    }

    private func installFindShortcutMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            InteractionMode.shared.isKeyboard = false
            return event
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Tab → enter keyboard navigation mode
            if event.keyCode == 48 {
                InteractionMode.shared.isKeyboard = true
            }

            // Cmd+F → focus the search field
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == .command && event.charactersIgnoringModifiers == "f" {
                if let window = NSApp.keyWindow {
                    for item in window.toolbar?.items ?? [] {
                        if let searchItem = item as? NSSearchToolbarItem {
                            window.makeFirstResponder(searchItem.searchField)
                            return nil
                        }
                    }
                }
                return event
            }

            // Arrow / page / home / end → navigate the list, unless a text field is editing.
            // Arrow keys carry .function (and sometimes .numericPad); strip those before
            // checking that no "real" modifier (Cmd/Option/Control/Shift) is held.
            let effectiveMods = mods.subtracting([.function, .numericPad])
            if effectiveMods.isEmpty,
               let notification = listNavNotification(for: event.keyCode),
               !isTextEditing() {
                InteractionMode.shared.isKeyboard = true
                NotificationCenter.default.post(name: notification, object: nil)
                return nil
            }
            return event
        }
    }

    private func listNavNotification(for keyCode: UInt16) -> Notification.Name? {
        switch keyCode {
        case 126: return .listNavUp
        case 125: return .listNavDown
        case 116: return .listNavPageUp
        case 121: return .listNavPageDown
        case 115: return .listNavHome
        case 119: return .listNavEnd
        default:  return nil
        }
    }

    private func isTextEditing() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSText
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutMenuItem()
            }
            CommandGroup(replacing: .help) { }
        }

        Window("About", id: "about-window") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

private struct AboutMenuItem: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About \(appName)") {
            openWindow(id: "about-window")
        }
    }

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "App"
    }
}
