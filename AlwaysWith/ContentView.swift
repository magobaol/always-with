//
//  ContentView.swift
//  AlwaysWith
//
//  Created by Francesco Face on 04/06/26.
//

import SwiftUI

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
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340)
                    .toolbar(removing: .sidebarToggle)
            } detail: {
                if let association = selectedAssociation {
                    AssociationDetailView(association: association, model: model)
                } else {
                    ContentUnavailableView(
                        "Select an extension",
                        systemImage: "doc.text",
                        description: Text("Pick a file extension from the list to view and change its default app.")
                    )
                }
            }
            .navigationTitle("Always with")
            .searchable(text: $search, prompt: "Filter by extension or app")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isLoading)
                }
            }

            StatusBar(
                totalCount: model.associations.count,
                filteredCount: filtered.count,
                updateState: updateChecker.state,
                currentVersion: updateChecker.currentVersion
            )
        }
        .task {
            guard autoLoad else { return }
            async let load: Void = model.load()
            async let updateCheck: Void = updateChecker.check()
            _ = await (load, updateCheck)
        }
        .frame(minWidth: 760, minHeight: 460)
    }

    @ViewBuilder
    private var sidebar: some View {
        if model.isLoading && model.associations.isEmpty {
            ProgressView("Scanning /Applications…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selection) {
                Section {
                    ForEach(filtered) { association in
                        AssociationRow(association: association)
                            .tag(association.id)
                    }
                } header: {
                    AssociationRowHeader()
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}

private let extensionColumnWidth: CGFloat = 130
private let appsColumnWidth: CGFloat = 50

private struct AssociationRowHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Extension")
                .frame(width: extensionColumnWidth, alignment: .leading)
            Text("Default app")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Apps")
                .frame(width: appsColumnWidth, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct AssociationRow: View {
    let association: ExtensionAssociation

    var body: some View {
        HStack(spacing: 10) {
            Text(".\(association.ext)")
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(".\(association.ext)")
                .frame(width: extensionColumnWidth, alignment: .leading)
            Text(association.currentDefaultApp?.name ?? "—")
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(association.currentDefaultApp == nil ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(association.supportingApps.count)")
                .foregroundStyle(.secondary)
                .frame(width: appsColumnWidth, alignment: .trailing)
        }
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
                Text("\(appName) v\(appVersion) · Made with ❤️ by Francesco Face")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
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
