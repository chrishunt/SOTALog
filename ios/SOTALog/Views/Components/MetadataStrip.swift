import SwiftUI

/// Compact metadata display for QSO entry: a single cloud of chips in stable
/// semantic order — [time] frequency, mode, RST sent, RST received,
/// [park ref ✓], [summit ref ✓], then name, QTH, and grid when populated.
/// Tap any chip to edit inline. Send saves the QSO.
/// The time chip appears when editing a QSO or after a time token ("1432Z") is typed.
/// Chips keep their natural size and wrap to a new row when they don't fit.
/// Data is never truncated; prose (the name) is width-capped so one long value
/// can't hog a whole row.
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
    @Binding var gridInput: String
    @Binding var timeOnInput: String
    var onTimeCommitted: () -> Void
    var onManualOverride: (String) -> Void
    var onModeToggle: () -> Void
    var onPOTAChanged: () -> Void
    var onSOTAChanged: () -> Void
    var isRadioConnected: Bool = false
    var onFrequencyChanged: () -> Void
    var onFrequencyCommitted: () -> Void
    var onSubmit: () -> Void

    @FocusState private var editFocus: EditField?
    @State private var editingField: EditField?

    private enum EditField: Hashable {
        case time, rstSent, rstReceived, frequency, name, qth, potaRef, sotaRef, grid
    }

    var body: some View {
        Group {
            if editingField != nil {
                editorField
            } else {
                chipRows
            }
        }
        .onChange(of: editFocus) { _, newValue in
            if newValue == nil {
                if editingField == .frequency {
                    onFrequencyCommitted()
                }
                if editingField == .time {
                    onTimeCommitted()
                }
                editingField = nil
            }
        }
    }

    // MARK: - Chip Rows

    private var chipRows: some View {
        FlowLayout(spacing: 6, rowSpacing: 4) {
            if !timeOnInput.isEmpty {
                segment(timeOnInput.insertingTimeSeparator + "Z", field: .time)
            }

            frequencySegment
            modeSegment
            segment(rstSent, field: .rstSent)
            segment(rstReceived, field: .rstReceived)

            if potaRefValid, let ref = potaRefFormatted {
                refSegment(ref, field: .potaRef, color: Color.appGreen)
            } else if !potaRefInput.isEmpty {
                segment(potaRefInput, field: .potaRef)
            }

            if sotaRefValid, let ref = sotaRefFormatted {
                refSegment(ref, field: .sotaRef, color: Color.appBlue)
            } else if !sotaRefInput.isEmpty {
                segment(sotaRefInput, field: .sotaRef)
            }

            if !name.isEmpty {
                segment(name, field: .name)
                    .layoutValue(key: FlowLayout.MaxWidthFraction.self, value: 0.6)
            }

            if !qth.isEmpty {
                segment(qth, field: .qth)
            }

            if !gridInput.isEmpty {
                segment(gridInput, field: .grid)
            }
        }
        .font(.appMetadata)
        .foregroundStyle(Color.appTextSecondary)
        .lineLimit(1)
    }

    // MARK: - Editor

    private var editorField: some View {
        Group {
            switch editingField {
            case .time:
                TextField("1432", text: $timeOnInput)
                    .focused($editFocus, equals: .time)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .onChange(of: timeOnInput) { _, newValue in
                        let sanitized = String(newValue.filter(\.isNumber).prefix(4))
                        if sanitized != newValue { timeOnInput = sanitized }
                    }
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
            case .grid:
                TextField("Grid", text: $gridInput)
                    .focused($editFocus, equals: .grid)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            case nil:
                EmptyView()
            }
        }
        .textFieldStyle(.roundedBorder)
        .font(.appMetadata)
        .submitLabel(.done)
        .onSubmit {
            let wasFrequency = editingField == .frequency
            let wasTime = editingField == .time
            editingField = nil
            editFocus = nil
            if wasFrequency { onFrequencyCommitted() }
            if wasTime { onTimeCommitted() }
            onSubmit()
        }
        .textContentType(.none)
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { }
        }
        #endif
    }

    // MARK: - Helpers

    private var modeSegment: some View {
        Button {
            onModeToggle()
        } label: {
            Text(mode)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.appTextSecondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var frequencySegment: some View {
        Button {
            editingField = .frequency
            editFocus = .frequency
        } label: {
            HStack(spacing: 3) {
                Text(frequencyText)
                if isRadioConnected {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(Color.appGreen)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appTextSecondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func segment(_ text: String, field: EditField) -> some View {
        Button {
            editingField = field
            editFocus = field
        } label: {
            Text(text)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.appTextSecondary.opacity(0.1), in: Capsule())
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
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.appTextSecondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
