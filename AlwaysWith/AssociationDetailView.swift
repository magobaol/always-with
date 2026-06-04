import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AssociationDetailView: View {
    let association: ExtensionAssociation
    @ObservedObject var model: AssociationsModel

    @State private var pendingSelection: String?
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var errorDismissTask: Task<Void, Never>?
    @State private var justUpdated = false
    @State private var flashDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            currentDefaultSection
            changeToSection

            if let errorMessage {
                errorBox(errorMessage)
            }

            HStack {
                Spacer()
                Button(action: applyChange) {
                    if isApplying {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 90)
                    } else {
                        Text("Set as default")
                    }
                }
                .buttonStyle(SetAsDefaultButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!canApply)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .onChange(of: association.id) { _, _ in
            pendingSelection = nil
            clearError()
            justUpdated = false
            flashDismissTask?.cancel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(".\(association.ext)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.brandAccentDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.brandAccentTint, in: RoundedRectangle(cornerRadius: 9))
                .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 8) {
                if let kindLabel {
                    Text(kindLabel)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(supportingAppsLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentDefaultSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Currently opens with")
            currentDefaultCard
        }
    }

    @ViewBuilder
    private var currentDefaultCard: some View {
        HStack(spacing: 12) {
            if let app = association.currentDefaultApp {
                Image(nsImage: AppIconCache.icon(for: app.url))
                    .resizable()
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13.5, weight: .bold))
                    Text(installPath(for: app))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if justUpdated {
                    Text("✓ Updated")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Color.brandSuccess)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.brandSuccess.opacity(0.13), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            } else {
                Text("No default app set")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(justUpdated ? Color.brandSuccess : Color.brandHairline,
                              lineWidth: justUpdated ? 2 : 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brandSuccess.opacity(justUpdated ? 0.22 : 0), lineWidth: 3)
                .padding(-3)
        )
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .animation(.easeInOut(duration: 0.25), value: justUpdated)
    }

    private var changeToSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Change to")
            changeToList
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var changeToList: some View {
        if association.supportingApps.isEmpty {
            Text("No apps declared support for this extension.")
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(association.supportingApps.enumerated()), id: \.element.bundleIdentifier) { index, app in
                        AppRow(
                            app: app,
                            isSelected: pendingSelection == app.bundleIdentifier,
                            isLast: index == association.supportingApps.count - 1,
                            installPath: installPath(for: app),
                            onTap: { pickApp(app) }
                        )
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(Color.brandHairline, lineWidth: 1)
            )
            .frame(maxHeight: .infinity)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(Color.brandTertiaryLabel)
    }

    private func errorBox(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var supportingAppsLabel: String {
        let count = association.supportingApps.count
        return "\(count) \(count == 1 ? "app" : "apps") can open it"
    }

    private var kindLabel: String? {
        if let uti = association.uti, let type = UTType(uti) {
            return type.localizedDescription
        }
        return UTType(filenameExtension: association.ext)?.localizedDescription
    }

    private var canApply: Bool {
        guard !isApplying, let selected = pendingSelection else { return false }
        return selected != association.currentDefaultApp?.bundleIdentifier
    }

    private func pickApp(_ app: AppRef) {
        if app.bundleIdentifier == pendingSelection {
            pendingSelection = nil
        } else {
            pendingSelection = app.bundleIdentifier
        }
        clearError()
    }

    private func applyChange() {
        guard let bundleIdentifier = pendingSelection else { return }
        clearError()
        isApplying = true
        Task {
            defer { isApplying = false }
            do {
                try await model.setDefaultApp(bundleIdentifier: bundleIdentifier, forExtension: association.ext)
                pendingSelection = nil
                triggerFlash()
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func triggerFlash() {
        flashDismissTask?.cancel()
        justUpdated = true
        flashDismissTask = Task {
            try? await Task.sleep(for: .milliseconds(1700))
            if !Task.isCancelled {
                justUpdated = false
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

    private func installPath(for app: AppRef) -> String {
        app.url.deletingLastPathComponent().path
    }
}

private struct AppRow: View {
    let app: AppRef
    let isSelected: Bool
    let isLast: Bool
    let installPath: String
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(nsImage: AppIconCache.icon(for: app.url))
                .resizable()
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.brandAccentDark : .primary)
                Text(installPath)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.brandTertiaryLabel)
            }
            Spacer()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.brandAccentTint : Color.clear)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 0.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private struct SetAsDefaultButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Color.brandAccent.opacity(isEnabled ? 1.0 : 0.4),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .shadow(color: .black.opacity(isEnabled ? 0.18 : 0), radius: 1, y: 1)
            .opacity(configuration.isPressed && isEnabled ? 0.85 : 1.0)
    }
}
