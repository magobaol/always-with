import SwiftUI
import UniformTypeIdentifiers

/// Sheet for manually adding a file extension that no installed app declares
/// (e.g. `.env`), so it becomes selectable in the list and can be reassigned.
struct AddExtensionView: View {
    let prefill: String
    @ObservedObject var model: AssociationsModel
    let onAdded: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isWorking = false
    @FocusState private var fieldFocused: Bool

    init(prefill: String, model: AssociationsModel, onAdded: @escaping (String) -> Void) {
        self.prefill = prefill
        self.model = model
        self.onAdded = onAdded
        _text = State(initialValue: prefill)
    }

    private var normalized: String? {
        AppScanner.normalizeExtension(text)
    }

    private var alreadyExists: Bool {
        guard let normalized else { return false }
        return model.associations.contains { $0.ext == normalized }
    }

    private var kindLabel: String? {
        guard let normalized else { return nil }
        return UTType(filenameExtension: normalized)?.localizedDescription
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add extension")
                .font(.nunitoBold(size: 18))

            VStack(alignment: .leading, spacing: 6) {
                Text("EXTENSION")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTertiaryLabel)
                HStack(spacing: 6) {
                    Text(".")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("env", text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, design: .monospaced))
                        .focused($fieldFocused)
                        .onSubmit(submit)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Color.brandHairline, lineWidth: 1)
                )
            }

            preview

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(action: submit) {
                    Text(alreadyExists ? "Show" : "Add")
                        .frame(minWidth: 48)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(normalized == nil || isWorking)
            }
        }
        .padding(22)
        .frame(width: 360)
        .onAppear { fieldFocused = true }
    }

    @ViewBuilder
    private var preview: some View {
        if normalized == nil {
            previewLine(icon: "character.cursor.ibeam", text: "Type a file extension, e.g. env")
        } else if alreadyExists {
            previewLine(icon: "checkmark.circle", text: "Already in the list — we'll jump to it.")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if let kindLabel {
                    previewLine(icon: "doc", text: kindLabel)
                }
                previewLine(icon: "app.badge", text: "We'll list every app that can open text files, so you can pick a default.")
            }
        }
    }

    private func previewLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandAccent)
                .font(.system(size: 12))
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func submit() {
        guard let normalized, !isWorking else { return }
        if alreadyExists {
            onAdded(normalized)
            dismiss()
            return
        }
        isWorking = true
        Task {
            let added = await model.addManualExtension(normalized)
            isWorking = false
            if let added {
                onAdded(added)
            }
            dismiss()
        }
    }
}
