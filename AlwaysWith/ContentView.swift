//
//  ContentView.swift
//  AlwaysWith
//
//  Created by Francesco Face on 04/06/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var model: AssociationsModel
    @StateObject private var updateChecker = UpdateChecker()
    @State private var search = ""
    @State private var selection: ExtensionAssociation.ID?

    private let autoLoad: Bool

    init(model: AssociationsModel? = nil, autoLoad: Bool = true) {
        _model = StateObject(wrappedValue: model ?? AssociationsModel())
        self.autoLoad = autoLoad
    }

    private var filtered: [ExtensionAssociation] {
        AssociationsModel.filter(model.associations, query: search)
    }

    private var selectedAssociation: ExtensionAssociation? {
        guard let selection else { return nil }
        return model.associations.first(where: { $0.id == selection })
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                sidebarPane
                    .frame(minWidth: 320, idealWidth: 372, maxHeight: .infinity)
                detailPane
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBar(
                totalCount: model.associations.count,
                filteredCount: filtered.count,
                updateState: updateChecker.state,
                currentVersion: updateChecker.currentVersion
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                BrandBlock()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .help("Refresh")
            }
            ToolbarItem(placement: .primaryAction) {
                FilterField(text: $search)
            }
        }
        .navigationTitle("")
        .task {
            guard autoLoad else { return }
            async let load: Void = model.load()
            async let updateCheck: Void = updateChecker.check()
            _ = await (load, updateCheck)
        }
        .frame(minWidth: 760, minHeight: 460)
    }

    @ViewBuilder
    private var sidebarPane: some View {
        if model.isLoading && model.associations.isEmpty {
            ProgressView("Scanning /Applications…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brandSidebarBackground)
        } else {
            Table(filtered, selection: $selection) {
                TableColumn("Extension") { association in
                    Text(".\(association.ext)")
                        .font(.system(size: 12, design: .monospaced))
                }
                .width(min: 80, ideal: 140)

                TableColumn("Default app") { association in
                    HStack(spacing: 8) {
                        if let app = association.currentDefaultApp {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                .resizable()
                                .frame(width: 17, height: 17)
                            Text(app.name)
                                .font(.system(size: 13))
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                }
                .width(min: 100, ideal: 132)

                TableColumn("Apps") { association in
                    Text("\(association.supportingApps.count)")
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(36)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .background(Color.brandSidebarBackground)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let association = selectedAssociation {
            AssociationDetailView(association: association, model: model)
        } else {
            EmptyStateView()
        }
    }
}

private struct BrandBlock: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("Always With")
                    .font(.nunitoExtraBold(size: 16.5))
                    .foregroundStyle(.primary)
                Text("Default apps, sorted.")
                    .font(.nunitoSemiBold(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FilterField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            TextField("Filter by extension or app", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .frame(width: 226)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 72, height: 72)
            Text("Pick an extension")
                .font(.nunitoBold(size: 21))
            Text("Choose a file extension on the left to see and change the app it always opens with.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StatusBar: View {
    let totalCount: Int
    let filteredCount: Int
    let updateState: UpdateState
    let currentVersion: String

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Text(countLabel)
                Spacer(minLength: 8)
                if case .available(let release) = updateState {
                    UpdateBadge(release: release, currentVersion: currentVersion)
                }
                HStack(spacing: 4) {
                    Text("\(appName) v\(appVersion) · Made with")
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color.brandAccent)
                        .font(.system(size: 10))
                    Text("by Francesco Face")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(Color.brandSidebarBackground)
        }
    }

    private var countLabel: String {
        if totalCount == 0 {
            return "No extensions"
        }
        if filteredCount == totalCount {
            return "\(totalCount) extensions"
        }
        return "\(filteredCount) of \(totalCount) extensions"
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "?"
    }

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "App"
    }
}

private struct UpdateBadge: View {
    let release: LatestRelease
    let currentVersion: String
    @State private var isPresentingSheet = false

    var body: some View {
        Button {
            isPresentingSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Update available: \(release.tag)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Show release notes and install")
        .sheet(isPresented: $isPresentingSheet) {
            UpdateSheet(release: release, currentVersion: currentVersion)
        }
    }
}

#Preview("With stub data") {
    let textEdit = AppRef(
        bundleIdentifier: "com.apple.TextEdit",
        name: "TextEdit",
        version: "1.18",
        url: URL(fileURLWithPath: "/System/Applications/TextEdit.app")
    )
    let preview = AppRef(
        bundleIdentifier: "com.apple.Preview",
        name: "Preview",
        version: "11.0",
        url: URL(fileURLWithPath: "/System/Applications/Preview.app")
    )
    let xcode = AppRef(
        bundleIdentifier: "com.apple.dt.Xcode",
        name: "Xcode",
        version: "26.3",
        url: URL(fileURLWithPath: "/Applications/Xcode.app")
    )

    let stub: [ExtensionAssociation] = [
        ExtensionAssociation(ext: "md",  uti: "net.daringfireball.markdown",
                             currentDefaultApp: textEdit,
                             supportingApps: [textEdit, xcode]),
        ExtensionAssociation(ext: "pdf", uti: "com.adobe.pdf",
                             currentDefaultApp: preview,
                             supportingApps: [preview, textEdit]),
        ExtensionAssociation(ext: "swift", uti: "public.swift-source",
                             currentDefaultApp: xcode,
                             supportingApps: [xcode, textEdit]),
        ExtensionAssociation(ext: "txt", uti: "public.plain-text",
                             currentDefaultApp: textEdit,
                             supportingApps: [textEdit, xcode, preview]),
    ]

    return ContentView(model: AssociationsModel(stub: stub), autoLoad: false)
}
