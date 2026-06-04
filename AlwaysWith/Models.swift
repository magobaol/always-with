import Foundation

nonisolated struct InstalledApp: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let version: String?
    let url: URL
    let declaredExtensions: Set<String>
}

nonisolated struct AppRef: Hashable, Sendable {
    let bundleIdentifier: String
    let name: String
    let version: String?
    let url: URL
}

nonisolated struct ExtensionAssociation: Identifiable, Hashable, Sendable {
    var id: String { ext }
    let ext: String
    let uti: String?
    let currentDefaultApp: AppRef?
    let supportingApps: [AppRef]
}
