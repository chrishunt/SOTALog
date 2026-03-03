import SwiftUI

/// Compact metadata display for QSO entry. Two lines:
/// Line 1 (always): frequency · RST sent · RST received [· park ref ✓] [· summit ref ✓]
/// Line 2 (when populated): name · QTH
/// Tap any segment to edit inline. Send saves the QSO.
struct MetadataStrip: View {
    @Binding var rstSent: String
    @Binding var rstReceived: String
    @Binding var frequencyText: String
    @Binding var mode: String
    @Binding var name: String
    @Binding var qth: String
    @Binding var potaRefInput: String
    var potaRefFormatted: String?
    var potaRefValid: Bool
    @Binding var sotaRefInput: String
    var sotaRefFormatted: String?
    var sotaRefValid: Bool
    var onManualOverride: (String) -> Void
    var onModeToggle: () -> Void
    var onPOTAChanged: () -> Void
    var onSOTAChanged: () -> Void
    var onFrequencyChanged: () -> Void
    var onSubmit: () -> Void

    @FocusState private var editFocus: EditField?
    @State private var editingField: EditField?

    private enum EditField: Hashable {
        case rstSent, rstReceived, frequency, name, qth, potaRef, sotaRef
    }

    private var isEditingLine1: Bool {
        switch editingField {
        case .rstSent, .rstReceived, .frequency, .potaRef, .sotaRef: return true
        default: return false
        }
    }

    private var isEditingLine2: Bool {
        switch editingField {
        case .name, .qth: return true
        default: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEditingLine1 {
                line1Editor
            } else {
                line1Display
            }

            if isEditingLine2 {
                line2Editor
            } else if !name.isEmpty || !qth.isEmpty {
                line2Display
            }
        }
        .onChange(of: editFocus) { _, newValue in
            if newValue == nil {
                editingField = nil
            }
        }
    }

    // MARK: - Line 1 Display

    private var line1Display: some View {
        HStack(spacing: 0) {
            segment(frequencyText, field: .frequency)
            dot
            modeSegment
            dot
            segment(rstSent, field: .rstSent)
            dot
            segment(rstReceived, field: .rstReceived)

            if potaRefValid, let ref = potaRefFormatted {
                dot
                refSegment(ref, field: .potaRef, color: Color.appGreen)
            } else if !potaRefInput.isEmpty {
                dot
                segment(potaRefInput, field: .potaRef)
            }

            if sotaRefValid, let ref = sotaRefFormatted {
                dot
                refSegment(ref, field: .sotaRef, color: Color.appBlue)
            } else if !sotaRefInput.isEmpty {
                dot
                segment(sotaRefInput, field: .sotaRef)
            }

            Spacer()
        }
        .font(.callout.monospacedDigit())
        .foregroundStyle(Color.appTextSecondary)
    }

    // MARK: - Line 1 Editor

    private var line1Editor: some View {
        Group {
            switch editingField {
            case .rstSent:
                TextField(mode == "SSB" ? "59" : "599", text: $rstSent)
                    .focused($editFocus, equals: .rstSent)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .onChange(of: rstSent) { _, _ in onManualOverride("rstSent") }
            case .rstReceived:
                TextField(mode == "SSB" ? "59" : "599", text: $rstReceived)
                    .focused($editFocus, equals: .rstReceived)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .onChange(of: rstReceived) { _, _ in onManualOverride("rstReceived") }
            case .frequency:
                TextField("14.060", text: $frequencyText)
                    .focused($editFocus, equals: .frequency)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .onChange(of: frequencyText) { _, _ in
                        onManualOverride("frequency")
                        onFrequencyChanged()
                    }
            case .potaRef:
                TextField("Park ref", text: $potaRefInput)
                    .focused($editFocus, equals: .potaRef)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: potaRefInput) { _, newValue in
                        let sanitized = newValue.sanitizedAlphanumeric
                        if sanitized != newValue { potaRefInput = sanitized }
                        onManualOverride("potaRef")
                        onPOTAChanged()
                    }
            case .sotaRef:
                TextField("Summit ref", text: $sotaRefInput)
                    .focused($editFocus, equals: .sotaRef)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: sotaRefInput) { _, newValue in
                        let sanitized = newValue.sanitizedAlphanumeric
                        if sanitized != newValue { sotaRefInput = sanitized }
                        onManualOverride("sotaRef")
                        onSOTAChanged()
                    }
            default:
                EmptyView()
            }
        }
        .textFieldStyle(.roundedBorder)
        .font(.callout.monospacedDigit())
        .submitLabel(.done)
        .onSubmit {
            editingField = nil
            editFocus = nil
            onSubmit()
        }
        .textContentType(.none)
    }

    // MARK: - Line 2 Display

    private var line2Display: some View {
        HStack(spacing: 0) {
            if !name.isEmpty {
                Button {
                    editingField = .name
                    editFocus = .name
                } label: {
                    Text(name)
                }
                .buttonStyle(.plain)
                .layoutPriority(-1)
            }

            if !name.isEmpty && !qth.isEmpty {
                dot
            }

            if !qth.isEmpty {
                segment(qth, field: .qth)
            }

            Spacer()
        }
        .font(.callout)
        .foregroundStyle(Color.appTextSecondary)
        .lineLimit(1)
    }

    // MARK: - Line 2 Editor

    private var line2Editor: some View {
        Group {
            switch editingField {
            case .name:
                TextField("Name", text: $name)
                    .focused($editFocus, equals: .name)
                    .autocorrectionDisabled()
                    .onChange(of: name) { _, _ in onManualOverride("name") }
            case .qth:
                TextField("QTH", text: $qth)
                    .focused($editFocus, equals: .qth)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: qth) { _, _ in onManualOverride("qth") }
            default:
                EmptyView()
            }
        }
        .textFieldStyle(.roundedBorder)
        .font(.callout)
        .submitLabel(.done)
        .onSubmit {
            editingField = nil
            editFocus = nil
            onSubmit()
        }
        .textContentType(.none)
    }

    // MARK: - Helpers

    private var modeSegment: some View {
        Button {
            onModeToggle()
        } label: {
            Text(mode)
        }
        .buttonStyle(.plain)
    }

    private func segment(_ text: String, field: EditField) -> some View {
        Button {
            editingField = field
            editFocus = field
        } label: {
            Text(text)
        }
        .buttonStyle(.plain)
    }

    private func refSegment(_ text: String, field: EditField, color: Color) -> some View {
        Button {
            editingField = field
            editFocus = field
        } label: {
            HStack(spacing: 3) {
                Text(text)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(color)
            }
        }
        .buttonStyle(.plain)
    }

    private var dot: some View {
        Text(" · ")
            .foregroundStyle(Color.appTextSecondary.opacity(0.5))
    }
}
