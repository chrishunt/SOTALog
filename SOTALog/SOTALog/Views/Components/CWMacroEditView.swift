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
                    FlowLayout(spacing: 8) {
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
                    Text(expandTemplate(template))
                        .font(.appTemplateCode)
                        .foregroundStyle(expandTemplate(template).isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
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
                    .disabled(label.isEmpty || template.isEmpty)
                }
            }
        }
    }
}

// MARK: - FlowLayout

/// Simple horizontal flow layout that wraps items to the next line.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
            totalHeight = max(totalHeight, y + rowHeight)
        }

        return ArrangeResult(positions: positions, size: CGSize(width: totalWidth, height: totalHeight))
    }
}
