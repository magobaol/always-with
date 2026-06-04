import SwiftUI

struct UpdateSheet: View {
    let release: LatestRelease
    let currentVersion: String

    @StateObject private var installer = UpdateInstaller()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            releaseNotesSection

            if case .failed(let message) = installer.state {
                errorBox(message)
            }

            Divider()

            footer
        }
        .padding(20)
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 720, minHeight: 380, idealHeight: 460)
        .font(.body)
        .foregroundStyle(.primary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Update available")
                .font(.title2.weight(.semibold))
            Text("v\(currentVersion) → \(release.tag)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var releaseNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Release notes")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if let body = release.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ReleaseNotesView(markdown: body)
                    } else {
                        Text("No release notes provided.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3))
            )
            .frame(minHeight: 160)
        }
    }

    private func errorBox(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            progressArea

            Spacer()

            Button("View on GitHub") {
                openURL(release.url)
            }
            .disabled(installer.isWorking)

            Button("Later") {
                dismiss()
            }
            .disabled(installer.isWorking)

            Button(action: startInstall) {
                Text(installButtonLabel)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canInstall)
        }
    }

    @ViewBuilder
    private var progressArea: some View {
        switch installer.state {
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 140)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .unpacking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Unpacking…").font(.caption).foregroundStyle(.secondary)
            }
        case .verifying:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Verifying…").font(.caption).foregroundStyle(.secondary)
            }
        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Installing…").font(.caption).foregroundStyle(.secondary)
            }
        case .idle, .failed:
            EmptyView()
        }
    }

    private var installButtonLabel: String {
        switch installer.state {
        case .failed: return "Retry"
        default: return "Install Update"
        }
    }

    private var canInstall: Bool {
        if installer.isWorking { return false }
        return release.assetURL != nil
    }

    private func startInstall() {
        Task {
            await installer.install(release)
        }
    }
}

private struct ReleaseNotesView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(ReleaseNoteBlock.parse(markdown).enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func render(_ block: ReleaseNoteBlock) -> some View {
        switch block.kind {
        case .heading(let level):
            Text(Self.attributed(block.text))
                .font(headingFont(for: level))
                .fontWeight(.semibold)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•").foregroundStyle(.secondary)
                Text(Self.attributed(block.text))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .paragraph:
            Text(Self.attributed(block.text))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .blank:
            Color.clear.frame(height: 4)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        default: return .headline
        }
    }

    static func attributed(_ raw: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return (try? AttributedString(markdown: raw, options: options)) ?? AttributedString(raw)
    }
}

struct ReleaseNoteBlock: Equatable {
    enum Kind: Equatable {
        case heading(Int)
        case bullet
        case paragraph
        case blank
    }
    let kind: Kind
    let text: String

    static func parse(_ raw: String) -> [ReleaseNoteBlock] {
        var blocks: [ReleaseNoteBlock] = []
        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                blocks.append(ReleaseNoteBlock(kind: .blank, text: ""))
                continue
            }
            if let (level, content) = parseHeading(trimmed) {
                blocks.append(ReleaseNoteBlock(kind: .heading(level), text: content))
                continue
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(ReleaseNoteBlock(kind: .bullet, text: String(trimmed.dropFirst(2))))
                continue
            }
            blocks.append(ReleaseNoteBlock(kind: .paragraph, text: trimmed))
        }
        return blocks
    }

    static func parseHeading(_ s: String) -> (level: Int, content: String)? {
        var level = 0
        var idx = s.startIndex
        while idx < s.endIndex, s[idx] == "#", level < 6 {
            level += 1
            idx = s.index(after: idx)
        }
        guard level >= 1 else { return nil }
        guard idx < s.endIndex, s[idx] == " " else { return nil }
        let content = String(s[s.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
        return (level, content)
    }
}

#Preview {
    UpdateSheet(
        release: LatestRelease(
            tag: "v1.0.0",
            name: "Release 1.0.0",
            url: URL(string: "https://github.com/magobaol/always-with/releases/tag/v1.0.0")!,
            body: """
            Version 1.0.0

            ## Install

            Download `AlwaysWith-1.0.0.zip`, unzip and move `AlwaysWith.app` to `/Applications`.

            This build is signed ad-hoc. On first launch macOS may block it as coming from an unidentified developer — right-click the app → **Open** to bypass Gatekeeper once.
            """,
            assetURL: URL(string: "https://github.com/magobaol/always-with/releases/download/v1.0.0/AlwaysWith-1.0.0.zip")!
        ),
        currentVersion: "0.9.0"
    )
}
