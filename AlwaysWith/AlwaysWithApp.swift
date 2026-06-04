//
//  AlwaysWithApp.swift
//  AlwaysWith
//
//  Created by Francesco Face on 04/06/26.
//

import SwiftUI
import AppKit
import CoreText

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
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isCmdF = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask) == .command
                && event.charactersIgnoringModifiers == "f"
            guard isCmdF, let window = NSApp.keyWindow else { return event }
            for item in window.toolbar?.items ?? [] {
                if let searchItem = item as? NSSearchToolbarItem {
                    window.makeFirstResponder(searchItem.searchField)
                    return nil
                }
            }
            return event
        }
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
