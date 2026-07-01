import Foundation
import AppKit
import Combine
import CoreServices
import UniformTypeIdentifiers

enum AssociationError: LocalizedError {
    case unknownUTI(extension: String)
    case launchServicesFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unknownUTI(let ext):
            return "Could not resolve a UTI for .\(ext)."
        case .launchServicesFailure(let status):
            return "Launch Services returned OSStatus \(status)."
        }
    }
}

@MainActor
final class AssociationsModel: ObservableObject {
    @Published private(set) var associations: [ExtensionAssociation] = []
    @Published private(set) var isLoading = false

    private let manualStore: ManualExtensionStore

    init(stub: [ExtensionAssociation] = [], manualStore: ManualExtensionStore = ManualExtensionStore()) {
        self.manualStore = manualStore
        self.associations = stub
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let manual = manualStore.all()
        let computed = await Task.detached(priority: .userInitiated) {
            Self.buildAssociations(manualExtensions: manual)
        }.value

        associations = computed
    }

    /// Adds a manually-typed extension to the persisted set and rebuilds the list
    /// so the new row appears. Returns the normalized extension, or `nil` if the
    /// input wasn't a valid bare extension.
    @discardableResult
    func addManualExtension(_ raw: String) async -> String? {
        guard let ext = manualStore.add(raw) else { return nil }
        await load()
        return ext
    }

    func setDefaultApp(bundleIdentifier: String, forExtension ext: String) async throws {
        guard let uti = Self.preferredUTI(forExtension: ext) else {
            throw AssociationError.unknownUTI(extension: ext)
        }

        let status = await Task.detached(priority: .userInitiated) {
            LSSetDefaultRoleHandlerForContentType(uti as CFString, .all, bundleIdentifier as CFString)
        }.value

        guard status == noErr else {
            throw AssociationError.launchServicesFailure(status)
        }

        let refreshedDefault = await Task.detached(priority: .userInitiated) {
            Self.defaultAppRef(forUTI: uti)
        }.value

        if let index = associations.firstIndex(where: { $0.ext == ext }) {
            let existing = associations[index]
            associations[index] = ExtensionAssociation(
                ext: existing.ext,
                uti: existing.uti,
                currentDefaultApp: refreshedDefault,
                supportingApps: existing.supportingApps
            )
        }
    }

    nonisolated static func filter(_ associations: [ExtensionAssociation], query rawQuery: String) -> [ExtensionAssociation] {
        let query = rawQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return associations }

        if query.hasPrefix(".") {
            let prefix = String(query.dropFirst())
            guard !prefix.isEmpty else { return associations }
            return associations.filter { $0.ext.hasPrefix(prefix) }
        }

        return associations.filter { association in
            if association.ext.contains(query) { return true }
            if association.currentDefaultApp?.name.lowercased().contains(query) == true { return true }
            return false
        }
    }

    nonisolated static func buildAssociations(manualExtensions: [String] = []) -> [ExtensionAssociation] {
        let apps = AppScanner.scanApplications()

        var extensionToApps: [String: [AppRef]] = [:]
        for app in apps {
            let reference = AppRef(bundleIdentifier: app.id, name: app.name, version: app.version, url: app.url)
            for ext in app.declaredExtensions {
                extensionToApps[ext, default: []].append(reference)
            }
        }

        // Ensure manually-added extensions have a row even when no app declares them.
        for ext in manualExtensions where extensionToApps[ext] == nil {
            extensionToApps[ext] = []
        }

        return extensionToApps.map { ext, supportingApps in
            let uti = preferredUTI(forExtension: ext)
            let defaultApp = uti.flatMap(defaultAppRef(forUTI:))

            // Orphan extension (no declaring app): offer text-capable apps as candidates.
            var combined = supportingApps.isEmpty ? candidateApps(forOrphanExtension: ext) : supportingApps
            if let defaultApp, !combined.contains(where: { $0.bundleIdentifier == defaultApp.bundleIdentifier }) {
                combined.append(defaultApp)
            }
            let sorted = combined.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            return ExtensionAssociation(
                ext: ext,
                uti: uti,
                currentDefaultApp: defaultApp,
                supportingApps: sorted
            )
        }
        .sorted { $0.ext < $1.ext }
    }

    /// Candidate apps for an extension that no installed app declares. Its UTI is
    /// dynamic, so there are no declared handlers; we fall back to every app that
    /// can open plain text — a sensible default for config files like `.env`.
    nonisolated static func candidateApps(forOrphanExtension ext: String) -> [AppRef] {
        var seen = Set<String>()
        var result: [AppRef] = []
        for type in [UTType.plainText, UTType.text] {
            for url in NSWorkspace.shared.urlsForApplications(toOpen: type) {
                guard let ref = appRef(from: url), seen.insert(ref.bundleIdentifier).inserted else { continue }
                result.append(ref)
            }
        }
        return result
    }

    nonisolated private static func preferredUTI(forExtension ext: String) -> String? {
        UTType(filenameExtension: ext)?.identifier
    }

    nonisolated static func appRef(from url: URL) -> AppRef? {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return AppRef(bundleIdentifier: bundleIdentifier, name: name, version: version, url: url)
    }

    nonisolated private static func defaultAppRef(forUTI uti: String) -> AppRef? {
        guard let unmanaged = LSCopyDefaultApplicationURLForContentType(
            uti as CFString,
            .all,
            nil
        ) else { return nil }
        let url = unmanaged.takeRetainedValue() as URL
        return appRef(from: url)
    }
}
