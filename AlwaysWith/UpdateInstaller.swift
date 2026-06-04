import Foundation
import AppKit
import Combine

enum UpdateInstallState: Equatable {
    case idle
    case downloading(progress: Double)
    case unpacking
    case verifying
    case installing
    case failed(String)
}

@MainActor
final class UpdateInstaller: NSObject, ObservableObject {
    @Published private(set) var state: UpdateInstallState = .idle

    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession?
    private var pendingContinuation: CheckedContinuation<URL, Error>?

    var isWorking: Bool {
        switch state {
        case .idle, .failed: return false
        default: return true
        }
    }

    func install(_ release: LatestRelease) async {
        guard let assetURL = release.assetURL else {
            state = .failed("No downloadable asset attached to release \(release.tag).")
            return
        }

        let runningAppURL = Self.resolveBundleURL(Bundle.main.bundleURL)
        guard runningAppURL.pathExtension == "app" else {
            state = .failed("Cannot locate the running .app bundle.")
            return
        }

        if !FileManager.default.isWritableFile(atPath: runningAppURL.deletingLastPathComponent().path) {
            state = .failed("Install location is not writable: \(runningAppURL.deletingLastPathComponent().path).")
            return
        }

        do {
            state = .downloading(progress: 0)
            let zipURL = try await download(from: assetURL)

            state = .unpacking
            let stagingDir = try unpack(zipURL: zipURL)

            state = .verifying
            let newAppURL = try locateApp(in: stagingDir, expectedBundleID: Bundle.main.bundleIdentifier)
            try Self.stripQuarantine(at: newAppURL)

            state = .installing
            try Self.scheduleSwap(newApp: newAppURL, oldApp: runningAppURL)

            try? FileManager.default.removeItem(at: zipURL)

            DispatchQueue.main.async {
                exit(0)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func download(from url: URL) async throws -> URL {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session
        defer {
            session.finishTasksAndInvalidate()
            self.session = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation
            let task = session.downloadTask(with: url)
            self.downloadTask = task
            task.resume()
        }
    }

    private func unpack(zipURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AlwaysWith-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", zipURL.path, tempDir.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateInstallError.unpackFailed(status: process.terminationStatus)
        }
        return tempDir
    }

    private func locateApp(in directory: URL, expectedBundleID: String?) throws -> URL {
        let items = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        guard let appURL = items.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateInstallError.appNotFoundInArchive
        }
        if let expectedBundleID,
           let newBundle = Bundle(url: appURL),
           let newID = newBundle.bundleIdentifier,
           newID != expectedBundleID {
            throw UpdateInstallError.bundleIDMismatch(expected: expectedBundleID, got: newID)
        }
        return appURL
    }

    nonisolated static func resolveBundleURL(_ url: URL, bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> URL {
        guard isTranslocated(url) else { return url }
        guard let bundleIdentifier else { return url }
        let candidates = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleIdentifier)
        for candidate in candidates where !isTranslocated(candidate) {
            return candidate
        }
        return url
    }

    nonisolated static func isTranslocated(_ url: URL) -> Bool {
        url.path.contains("/AppTranslocation/")
    }

    nonisolated static func stripQuarantine(at appURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-dr", "com.apple.quarantine", appURL.path]
        try process.run()
        process.waitUntilExit()
    }

    nonisolated static func scheduleSwap(newApp: URL, oldApp: URL) throws {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AlwaysWith-swap-\(UUID().uuidString).sh")
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/bash
        set -e
        TARGET_PID=\(pid)
        NEW_APP=\(Self.shellEscape(newApp.path))
        OLD_APP=\(Self.shellEscape(oldApp.path))
        while kill -0 $TARGET_PID 2>/dev/null; do sleep 0.2; done
        sleep 0.5
        rm -rf "$OLD_APP"
        mv "$NEW_APP" "$OLD_APP"
        open "$OLD_APP"
        sleep 1
        rm -- "$0"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        try process.run()
    }

    nonisolated static func shellEscape(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

extension UpdateInstaller: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            progress = 0
        }
        Task { @MainActor [weak self] in
            self?.state = .downloading(progress: progress)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let cachedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AlwaysWith-update-\(UUID().uuidString).zip")
        do {
            try FileManager.default.moveItem(at: location, to: cachedURL)
            Task { @MainActor [weak self] in
                self?.resumeDownload(with: .success(cachedURL))
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.resumeDownload(with: .failure(error))
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        Task { @MainActor [weak self] in
            self?.resumeDownload(with: .failure(error))
        }
    }

    private func resumeDownload(with result: Result<URL, Error>) {
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil
        downloadTask = nil
        switch result {
        case .success(let url): continuation.resume(returning: url)
        case .failure(let err): continuation.resume(throwing: err)
        }
    }
}

enum UpdateInstallError: LocalizedError {
    case unpackFailed(status: Int32)
    case appNotFoundInArchive
    case bundleIDMismatch(expected: String, got: String)

    var errorDescription: String? {
        switch self {
        case .unpackFailed(let status):
            return "Unpacking the update failed (ditto exited with status \(status))."
        case .appNotFoundInArchive:
            return "The downloaded archive did not contain a .app bundle."
        case .bundleIDMismatch(let expected, let got):
            return "Bundle identifier mismatch (expected \(expected), got \(got))."
        }
    }
}
