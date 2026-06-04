import Foundation
import Combine

struct LatestRelease: Equatable, Sendable {
    let tag: String
    let name: String?
    let url: URL
    let body: String?
    let assetURL: URL?
}

enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case available(LatestRelease)
    case error(String)
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var state: UpdateState = .idle

    private let repoOwner: String
    private let repoName: String

    init(repoOwner: String = "magobaol", repoName: String = "always-with") {
        self.repoOwner = repoOwner
        self.repoName = repoName
    }

    var currentVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }

    func check() async {
        state = .checking
        do {
            let release = try await fetchLatestRelease()
            if Self.isVersion(release.tag, newerThan: currentVersion) {
                state = .available(release)
            } else {
                state = .upToDate
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func fetchLatestRelease() async throws -> LatestRelease {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateCheckError.invalidResponse
        }
        if http.statusCode == 404 {
            throw UpdateCheckError.noReleaseYet
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UpdateCheckError.httpStatus(http.statusCode)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try Self.parseRelease(from: json)
    }

    nonisolated static func parseRelease(from json: [String: Any]) throws -> LatestRelease {
        guard let tag = json["tag_name"] as? String,
              let htmlURLString = json["html_url"] as? String,
              let htmlURL = URL(string: htmlURLString) else {
            throw UpdateCheckError.unexpectedFormat
        }
        let body = json["body"] as? String
        let assetURL = extractZipAssetURL(from: json["assets"])
        return LatestRelease(
            tag: tag,
            name: json["name"] as? String,
            url: htmlURL,
            body: body,
            assetURL: assetURL
        )
    }

    nonisolated static func extractZipAssetURL(from rawAssets: Any?) -> URL? {
        guard let assets = rawAssets as? [[String: Any]] else { return nil }
        for asset in assets {
            guard let name = asset["name"] as? String,
                  name.lowercased().hasSuffix(".zip"),
                  let urlString = asset["browser_download_url"] as? String,
                  let url = URL(string: urlString) else { continue }
            return url
        }
        return nil
    }

    nonisolated static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let remoteComponents = parseVersion(remote)
        let localComponents = parseVersion(local)
        let count = max(remoteComponents.count, localComponents.count)
        for index in 0..<count {
            let remoteValue = index < remoteComponents.count ? remoteComponents[index] : 0
            let localValue = index < localComponents.count ? localComponents[index] : 0
            if remoteValue > localValue { return true }
            if remoteValue < localValue { return false }
        }
        return false
    }

    nonisolated static func parseVersion(_ raw: String) -> [Int] {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        let core = trimmed.split(separator: "-").first.map(String.init) ?? trimmed
        return core.split(separator: ".").map { component in
            Int(component.filter(\.isNumber)) ?? 0
        }
    }
}

enum UpdateCheckError: LocalizedError {
    case invalidResponse
    case noReleaseYet
    case httpStatus(Int)
    case unexpectedFormat

    var errorDescription: String? {
        switch self {
        case .invalidResponse:     return "Invalid response from GitHub."
        case .noReleaseYet:        return "No releases published yet."
        case .httpStatus(let code): return "GitHub returned HTTP \(code)."
        case .unexpectedFormat:    return "Unexpected response format."
        }
    }
}
