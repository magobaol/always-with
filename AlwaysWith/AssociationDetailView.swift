import SwiftUI

struct AssociationDetailView: View {
    let association: ExtensionAssociation
    @ObservedObject var model: AssociationsModel

    @State private var selectedBundleIdentifier: String?
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var errorDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            Text("Supporting apps")
                .font(.headline)

            if association.supportingApps.isEmpty {
                Text("No apps declared support for this extension.")
                    .foregroundStyle(.secondary)
            } else {
                List(association.supportingApps, id: \.bundleIdentifier, selection: $selectedBundleIdentifier) { app in
                    HStack(spacing: 8) {
                        Text(app.name)
                        if let version = app.version {
                            Text(version)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if app.bundleIdentifier == association.currentDefaultApp?.bundleIdentifier {
                            CurrentBadge()
                                .transition(.scale.combined(with: .opacity))
                        }
                        Spacer()
                        Text(app.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .tag(app.bundleIdentifier)
                }
                .listStyle(.bordered)
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: association.currentDefaultApp?.bundleIdentifier)
            }

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack {
                Spacer()
                Button(action: applyChange) {
                    if isApplying {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Set as default")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canApply)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .onChange(of: association.id) { _, _ in
            selectedBundleIdentifier = nil
            clearError()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(".\(association.ext)")
                .font(.system(.title2, design: .monospaced))
            if let uti = association.uti {
                Text("UTI: \(uti)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("UTI: unresolved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Text("Current default:")
                    .foregroundStyle(.secondary)
                Text(currentDefaultLabel)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.25), value: association.currentDefaultApp?.bundleIdentifier)
            }
        }
    }

    private var currentDefaultLabel: String {
        guard let app = association.currentDefaultApp else { return "—" }
        if let version = app.version {
            return "\(app.name) \(version)"
        }
        return app.name
    }

    private var canApply: Bool {
        guard !isApplying else { return false }
        guard let selected = selectedBundleIdentifier else { return false }
        return selected != association.currentDefaultApp?.bundleIdentifier
    }

    private func applyChange() {
        guard let bundleIdentifier = selectedBundleIdentifier else { return }
        clearError()
        isApplying = true
        Task {
            defer { isApplying = false }
            do {
                try await model.setDefaultApp(bundleIdentifier: bundleIdentifier, forExtension: association.ext)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                errorMessage = nil
            }
        }
    }

    private func clearError() {
        errorDismissTask?.cancel()
        errorMessage = nil
    }
}

private struct CurrentBadge: View {
    var body: some View {
        Text("CURRENT")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.accentColor, in: Capsule())
    }
}
