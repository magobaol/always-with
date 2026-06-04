import Foundation
import CoreServices
import UniformTypeIdentifiers

enum AppScanner {
    nonisolated static func scanApplications(at root: URL = URL(fileURLWithPath: "/Applications")) -> [InstalledApp] {
        let bundleURLs = findAppBundles(in: root, maxDepth: 2)
        var seen = Set<String>()
        var apps: [InstalledApp] = []
        for url in bundleURLs {
            guard let app = makeInstalledApp(from: url) else { continue }
            if seen.insert(app.id).inserted {
                apps.append(app)
            }
        }
        return apps
    }

    nonisolated private static func findAppBundles(in directory: URL, maxDepth: Int) -> [URL] {
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [URL] = []
        for item in items {
            if item.pathExtension == "app" {
                result.append(item)
            } else if maxDepth > 0 {
                let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDirectory {
                    result.append(contentsOf: findAppBundles(in: item, maxDepth: maxDepth - 1))
                }
            }
        }
        return result
    }

    nonisolated private static func makeInstalledApp(from url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return nil }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

        let documentTypes = bundle.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]] ?? []
        let extensions = extensions(fromDocumentTypes: documentTypes)

        return InstalledApp(
            id: bundleIdentifier,
            name: displayName,
            version: version,
            url: url,
            declaredExtensions: extensions
        )
    }

    nonisolated static func extensions(fromDocumentTypes documentTypes: [[String: Any]]) -> Set<String> {
        var result = Set<String>()
        for entry in documentTypes {
            if let declared = entry["CFBundleTypeExtensions"] as? [String] {
                for raw in declared {
                    let normalized = raw.trimmingCharacters(in: .whitespaces).lowercased()
                    guard !normalized.isEmpty, normalized != "*" else { continue }
                    result.insert(normalized)
                }
            }
            if let contentTypes = entry["LSItemContentTypes"] as? [String] {
                for identifier in contentTypes {
                    for ext in extensionsForUTI(identifier) {
                        result.insert(ext)
                    }
                }
            }
        }
        return result
    }

    nonisolated static func extensionsForUTI(_ identifier: String) -> Set<String> {
        guard let type = UTType(identifier) else { return [] }
        let tags = type.tags[.filenameExtension] ?? []
        var result = Set<String>()
        for tag in tags {
            let normalized = tag.trimmingCharacters(in: .whitespaces).lowercased()
            guard !normalized.isEmpty else { continue }
            result.insert(normalized)
        }
        return result
    }
}
