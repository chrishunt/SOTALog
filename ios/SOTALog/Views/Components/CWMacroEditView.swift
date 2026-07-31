import SwiftUI

struct CWMacroEditView: View {
    let macro: CWMacro
    let expandTemplate: (String) -> String
    let onSave: (CWMacro) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var label: String
    @State private var template: String

    private static let variables = [
        "{myCall}", "{call}", "{rst}",
        "{mySOTA}", "{myPOTA}", "{activity}",
    ]

    init(macro: CWMacro, expandTemplate: @escaping (String) -> String, onSave: @escaping (CWMacro) -> Void, onReset: @escaping () -> Void) {
        self.macro = macro
        self.expandTemplate = expandTemplate
        self.onSave = onSave
        self.onReset = onReset
        self._label = State(initialValue: macro.label)
        self._template = State(initialValue: macro.template)
    }

    var body: some View {
        let preview = expandTemplate(template)
        NavigationStack {
            Form {
                Section("Button Label") {
                    TextField("Label", text: $label)
                        .autocorrectionDisabled()
                }

                Section("Template") {
                    TextField("Template", text: $template)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.appTemplateCode)
                }

                Section("Variables") {
                    FlowLayout(spacing: 8, rowSpacing: 8) {
                        ForEach(Self.variables, id: \.self) { variable in
                            Text(variable)
                                .font(.appVariableChip)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.appTextSecondary.opacity(0.1), in: Capsule())
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }

                Section("Preview") {
                    Text(preview)
                        .font(.appTemplateCode)
                        .foregroundStyle(preview.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                    if !preview.isEmpty {
                        Text("\(preview.count)/24")
                            .font(.caption)
                            .foregroundStyle(preview.count > 24 ? Color.appRed : Color.appTextSecondary)
                    }
                }

                Section {
                    Button("Reset to Default") {
                        onReset()
                        dismiss()
                    }
                    .foregroundStyle(Color.appRed)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Edit Macro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = macro
                        updated.label = label
                        updated.template = template
                        onSave(updated)
                        dismiss()
                    }
                    .bold()
                    .disabled(label.isEmpty || template.isEmpty || preview.count > 24)
                }
            }
        }
    }
}
