import SwiftUI
import HamCore

/// The QSO entry fields above the callsign, in two parts.
///
/// The station band says who the other station is: each callsign list's note,
/// then a line with the name, QTH and grid. It spans the panel's width on a
/// raised surface and appears only when it has something to show.
///
/// Below it, a cloud of chips holds what is set for this contact, in stable
/// order: [time] frequency, mode, RST sent, RST received, [park ref ✓],
/// [summit ref ✓]. The time chip appears when editing a QSO or after a time
/// token ("1432Z") is typed. Chips keep their natural size and wrap rather
/// than truncate.
///
/// Tap any value to edit it inline: the line or chip row it sits on becomes a
/// text field. Send saves the QSO.
struct MetadataStrip: View {
    /// What each callsign list says about the station, one line per list.
    var notes: [CallsignMarks.Note] = []
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
    @ScaledMetric(relativeTo: .footnote) private var noteEmojiWidth: CGFloat = 22

    private enum EditField: Hashable {
        case time, rstSent, rstReceived, frequency, name, qth, potaRef, sotaRef, grid

        /// Fields about the other station, shown in the band rather than the chips.
        var isStation: Bool { self == .name || self == .qth || self == .grid }
    }

    private var isEditingStation: Bool { editingField?.isStation == true }
    private var hasStationLine: Bool { !name.isEmpty || !qth.isEmpty || !gridInput.isEmpty }
    private var showsBand: Bool { !notes.isEmpty || hasStationLine || isEditingStation }

    var body: some View {
        VStack(spacing: 0) {
            if showsBand {
                stationBand
                    .transition(.opacity)
            }

            Group {
                if editingField != nil && !isEditingStation {
                    editorField
                } else {
                    chipRows
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.15), value: showsBand)
        .animation(.easeInOut(duration: 0.15), value: notes)
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
        }
        .font(.appMetadata)
        .foregroundStyle(Color.appTextSecondary)
        .lineLimit(1)
    }

    // MARK: - Station Band

    private var stationBand: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !notes.isEmpty {
                noteLines
            }

            if isEditingStation {
                editorField
            } else if hasStationLine {
                stationLine
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.appSurfaceRaised)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// One line per list, cut off rather than wrapped. Emoji sit in a fixed
    /// column so the notes line up.
    private var noteLines: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(notes, id: \.emoji) { note in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(note.emoji)
                        .frame(width: noteEmojiWidth, alignment: .leading)
                    Text(note.text)
                }
                .font(.appLabel)
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The name, large, with QTH and grid beside it. They move under the name
    /// when it is too long to share the line.
    private var stationLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                stationName
                stationLocation
            }
            VStack(alignment: .leading, spacing: 0) {
                stationName
                stationLocation
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var stationName: some View {
        if !name.isEmpty {
            stationButton(name, field: .name, underline: Color.appTextPrimary.opacity(0.25))
                .font(.appStationName)
                .foregroundStyle(Color.appTextPrimary)
                .accessibilityLabel("Name, \(name)")
        }
    }

    /// QTH and grid carry their own side padding so short values like "CA"
    /// stay as easy to tap as the chips were; the negative leading padding
    /// keeps the text aligned with the name.
    @ViewBuilder
    private var stationLocation: some View {
        if !qth.isEmpty || !gridInput.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if !qth.isEmpty {
                    stationButton(qth, field: .qth, underline: Self.locationUnderline, sidePadding: Self.locationSidePadding)
                        .accessibilityLabel("QTH, \(qth)")
                }
                if !qth.isEmpty && !gridInput.isEmpty {
                    Text("·")
                        .foregroundStyle(Color.appTextTertiary)
                        .accessibilityHidden(true)
                }
                if !gridInput.isEmpty {
                    stationButton(gridInput, field: .grid, underline: Self.locationUnderline, sidePadding: Self.locationSidePadding)
                        .accessibilityLabel("Grid, \(gridInput)")
                }
            }
            .padding(.leading, -Self.locationSidePadding)
            .font(.appStationDetail)
            .foregroundStyle(Color.appTextSecondary)
        }
    }

    private static let locationSidePadding: CGFloat = 6
    private static let locationUnderline = Color.appTextSecondary.opacity(0.55)

    /// A faint dotted underline marks a value you can tap to edit, setting it
    /// apart from the read-only list notes above.
    private func stationButton(_ text: String, field: EditField, underline: Color, sidePadding: CGFloat = 0) -> some View {
        Button {
            beginEditing(field)
        } label: {
            Text(text)
                .underline(pattern: .dot, color: underline)
                .padding(.horizontal, sidePadding)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Opens `field` for editing. A frequency or time edit still open is
    /// committed first: focus moves straight to the new field without passing
    /// through nil, so the commit in `onChange(of: editFocus)` never sees it.
    private func beginEditing(_ field: EditField) {
        if editingField == .frequency { onFrequencyCommitted() }
        if editingField == .time { onTimeCommitted() }
        editingField = field
        editFocus = field
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
            beginEditing(.frequency)
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
            beginEditing(field)
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
            beginEditing(field)
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
