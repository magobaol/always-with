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
    @State private var extW: CGFloat = 150
    @State private var appW: CGFloat = 132
    @State private var scrollTarget: ExtensionAssociation.ID?
    @FocusState private var focus: AppFocus?

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

    private var sidebarMinWidth: CGFloat {
        // leading pad + extW + separator + appW + separator + min Apps column + trailing pad
        18 + extW + 9 + appW + 9 + 50 + 14
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HSplitView {
                    sidebarPane
                        .frame(minWidth: sidebarMinWidth, idealWidth: 372, maxHeight: .infinity)
                    detailPane
                        .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                }
                .focusSection()
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
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Filter by extension or app")
        .onChange(of: search) { oldValue, newValue in
            if !oldValue.isEmpty, newValue.isEmpty, let selection {
                scrollTarget = selection
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
    }

    @ViewBuilder
    private var sidebarPane: some View {
        if model.isLoading && model.associations.isEmpty {
            ProgressView("Scanning /Applications…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brandSidebarBackground)
        } else {
            ExtensionListView(
                rows: filtered,
                selection: $selection,
                extW: $extW,
                appW: $appW,
                scrollTarget: scrollTarget,
                onScrolled: { scrollTarget = nil },
                focus: $focus
            )
        }
    }

    private var detailPane: some View {
        ZStack {
            Color.white
            if let association = selectedAssociation {
                AssociationDetailView(association: association, model: model, focus: $focus)
            } else {
                EmptyStateView()
            }
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

private struct ExtensionListView: View {
    let rows: [ExtensionAssociation]
    @Binding var selection: ExtensionAssociation.ID?
    @Binding var extW: CGFloat
    @Binding var appW: CGFloat
    let scrollTarget: ExtensionAssociation.ID?
    let onScrolled: () -> Void
    @FocusState.Binding var focus: AppFocus?

    @State private var draggingSep: Int? = nil
    @ObservedObject private var interaction = InteractionMode.shared

    private var isListFocused: Bool { focus == .mainList }

    private let separatorWidth: CGFloat = 9
    private let leadingPad: CGFloat = 18
    private let trailingPad: CGFloat = 14
    private let headerColor = Color(red: 0x8A / 255, green: 0x8A / 255, blue: 0x8E / 255)

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Rectangle()
                .fill(Color.brandHairline)
                .frame(height: 0.5)
            list
        }
        .background(Color.brandSidebarBackground)
        .overlay(
            Rectangle()
                .strokeBorder(
                    (isListFocused && interaction.isKeyboard) ? Color.brandAccent : Color.clear,
                    lineWidth: 2
                )
        )
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Extension")
                .frame(width: extW, alignment: .leading)
                .padding(.leading, leadingPad)
            separator(index: 0)
            Text("Default app")
                .frame(width: appW, alignment: .leading)
                .padding(.leading, 12)
            separator(index: 1)
            Text("Apps")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .padding(.trailing, trailingPad)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(headerColor)
        .frame(height: 28)
    }

    private func separator(index: Int) -> some View {
        let isActive = draggingSep == index
        return ZStack {
            Color.clear
            Rectangle()
                .fill(isActive ? Color.brandAccent : Color.brandHairline)
                .frame(width: isActive ? 2 : 1)
        }
        .frame(width: separatorWidth)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.resizeLeftRight.set()
            } else if draggingSep != index {
                NSCursor.arrow.set()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if draggingSep != index {
                        draggingSep = index
                    }
                    let delta = value.translation.width
                    if index == 0 {
                        extW = clamp(extW + delta, min: 80, max: 300)
                    } else {
                        appW = clamp(appW + delta, min: 80, max: 300)
                    }
                }
                .onEnded { _ in
                    draggingSep = nil
                    NSCursor.arrow.set()
                }
        )
    }

    @ViewBuilder
    private var list: some View {
        if rows.isEmpty {
            VStack {
                Text("No matches")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, association in
                            rowView(association: association, isEven: index.isMultiple(of: 2))
                                .id(association.id)
                        }
                    }
                }
                .focusable(true)
                .focused($focus, equals: .mainList)
                .focusEffectDisabled()
                .onReceive(NotificationCenter.default.publisher(for: .listNavUp)) { _ in
                    guard isListFocused else { return }
                    moveSelection(by: -1, proxy: proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: .listNavDown)) { _ in
                    guard isListFocused else { return }
                    moveSelection(by: 1, proxy: proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: .listNavPageUp)) { _ in
                    guard isListFocused else { return }
                    moveSelection(by: -10, proxy: proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: .listNavPageDown)) { _ in
                    guard isListFocused else { return }
                    moveSelection(by: 10, proxy: proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: .listNavHome)) { _ in
                    guard isListFocused else { return }
                    jumpSelection(to: 0, proxy: proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: .listNavEnd)) { _ in
                    guard isListFocused else { return }
                    jumpSelection(to: rows.count - 1, proxy: proxy)
                }
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    guard rows.contains(where: { $0.id == target }) else {
                        onScrolled()
                        return
                    }
                    proxy.scrollTo(target, anchor: .center)
                    onScrolled()
                }
            }
        }
    }

    private func moveSelection(by delta: Int, proxy: ScrollViewProxy) {
        guard !rows.isEmpty else { return }
        let currentIndex = rows.firstIndex { $0.id == selection } ?? -1
        let nextIndex: Int
        if currentIndex < 0 {
            nextIndex = delta > 0 ? 0 : rows.count - 1
        } else {
            nextIndex = max(0, min(rows.count - 1, currentIndex + delta))
        }
        let newID = rows[nextIndex].id
        selection = newID
        proxy.scrollTo(newID, anchor: nil)
    }

    private func jumpSelection(to index: Int, proxy: ScrollViewProxy) {
        guard !rows.isEmpty, index >= 0, index < rows.count else { return }
        let newID = rows[index].id
        selection = newID
        proxy.scrollTo(newID, anchor: nil)
    }

    private func rowView(association: ExtensionAssociation, isEven: Bool) -> some View {
        let isSelected = (selection == association.id)
        let background: Color = {
            if isSelected { return Color.brandAccentTint }
            if isEven { return Color.black.opacity(0.025) }
            return Color.clear
        }()
        return HStack(spacing: 0) {
            Text(".\(association.ext)")
                .font(.system(size: 12,
                              weight: isSelected ? .bold : .regular,
                              design: .monospaced))
                .foregroundStyle(isSelected ? Color.brandAccentDark : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: extW, alignment: .leading)
                .padding(.leading, leadingPad)

            Color.clear.frame(width: separatorWidth)

            HStack(spacing: 8) {
                if let app = association.currentDefaultApp {
                    Image(nsImage: AppIconCache.icon(for: app.url))
                        .resizable()
                        .frame(width: 17, height: 17)
                    Text(app.name)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? Color.brandAccentDark : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .frame(width: appW, alignment: .leading)
            .padding(.leading, 12)

            Color.clear.frame(width: separatorWidth)

            Text("\(association.supportingApps.count)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .padding(.trailing, trailingPad)
        }
        .frame(height: 36)
        .background(background)
        .contentShape(Rectangle())
        .onTapGesture {
            selection = association.id
        }
    }

    private func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.max(lower, Swift.min(upper, value))
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
