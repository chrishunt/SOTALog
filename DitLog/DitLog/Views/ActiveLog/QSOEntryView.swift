import SwiftUI

struct QSOEntryView: View {
    let database: AppDatabase
    let log: Log
    @Binding var editingQSO: QSO?
    @Binding var pendingSpot: Spot?
    let onSave: (QSO) -> Void

    @State private var viewModel: QSOEntryViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case callsign, frequency, name, qth, sotaRef, potaRef
    }

    init(database: AppDatabase, log: Log, editingQSO: Binding<QSO?>, pendingSpot: Binding<Spot?>, onSave: @escaping (QSO) -> Void) {
        self.database = database
        self.log = log
        self._editingQSO = editingQSO
        self._pendingSpot = pendingSpot
        self.onSave = onSave
        self._viewModel = State(initialValue: QSOEntryViewModel(database: database, log: log))
    }

    var body: some View {
        VStack(spacing: 12) {
            // Editing banner
            if viewModel.isEditing {
                editingBanner
            }

            // Callsign row
            callsignRow

            // RST + Frequency row
            rstFrequencyRow

            // Name + QTH row
            nameQTHRow

            // P2P field (only if at a park)
            if log.isPOTA {
                p2pRow
            }

            // S2S field (only if at a summit)
            if log.isSOTA {
                s2sRow
            }

            // LOG button
            logButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear {
            focusedField = .callsign
        }
        .onChange(of: editingQSO) { _, newValue in
            if let qso = newValue {
                viewModel.loadForEditing(qso)
                focusedField = .callsign
            }
        }
        .onChange(of: pendingSpot) { _, newValue in
            if let spot = newValue {
                viewModel.prefillFromSpot(spot)
                pendingSpot = nil
                focusedField = .callsign
            }
        }
    }

    // MARK: - Editing Banner

    private var editingBanner: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.orange)
            Text("Editing: \(viewModel.parsedCallsign)")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            Spacer()
            Button("Cancel") {
                viewModel.cancelEditing()
                editingQSO = nil
                focusedField = .callsign
            }
            .font(.subheadline)
            .foregroundStyle(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Callsign Row

    private var callsignRow: some View {
        HStack {
            TextField("CALLSIGN", text: $viewModel.entryText)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.6)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .callsign)
                .submitLabel(.send)
                .onSubmit {
                    submitQSO()
                }
                .onChange(of: viewModel.entryText) { _, newValue in
                    viewModel.entryText = newValue.sanitizedOmnifield
                    viewModel.parseEntry()
                    viewModel.callsignChanged()
                }

            if viewModel.timesWorked > 0 {
                Text("x\(viewModel.timesWorked)")
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - RST + Frequency

    private var rstFrequencyRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RST Sent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                RSTField(value: $viewModel.rstSent)
                    .onChange(of: focusedField) { _, newValue in
                        if newValue == .callsign { return }
                        // If user taps into RST directly, mark manual override
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("RST Rcvd")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                RSTField(value: $viewModel.rstReceived)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Freq MHz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("14.060", text: $viewModel.frequencyText)
                    .font(.body.monospacedDigit())
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .focused($focusedField, equals: .frequency)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.frequencyText) { _, _ in
                        if focusedField == .frequency {
                            viewModel.markManualOverride("frequency")
                        }
                    }
            }
        }
    }

    // MARK: - Name + QTH

    private var nameQTHRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Name", text: $viewModel.name)
                    .focused($focusedField, equals: .name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("QTH")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("QTH", text: $viewModel.qth)
                    .textInputAutocapitalization(.characters)
                    .focused($focusedField, equals: .qth)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.qth) { _, _ in
                        if focusedField == .qth {
                            viewModel.markManualOverride("qth")
                        }
                    }
            }
            .frame(maxWidth: 120)
        }
    }

    // MARK: - P2P

    private var p2pRow: some View {
        HStack {
            Text("P2P:")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            TextField("Park (e.g. US4431)", text: $viewModel.potaRefInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .potaRef)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .onChange(of: viewModel.potaRefInput) { _, newValue in
                    if focusedField == .potaRef {
                        viewModel.markManualOverride("potaRef")
                        viewModel.potaRefInput = newValue.sanitizedAlphanumeric
                    }
                    viewModel.validatePOTARef()
                }

            if let formatted = viewModel.potaRefFormatted {
                Text(formatted)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if let name = viewModel.potaRefName {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if viewModel.potaRefValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - S2S

    private var s2sRow: some View {
        HStack {
            Text("S2S:")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            TextField("Summit (e.g. W4CCM001)", text: $viewModel.sotaRefInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .sotaRef)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .onChange(of: viewModel.sotaRefInput) { _, newValue in
                    if focusedField == .sotaRef {
                        viewModel.markManualOverride("sotaRef")
                        viewModel.sotaRefInput = newValue.sanitizedAlphanumeric
                    }
                    viewModel.validateSOTARef()
                }

            if let formatted = viewModel.sotaRefFormatted {
                Text(formatted)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if viewModel.sotaRefValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            submitQSO()
        } label: {
            Text(viewModel.isEditing ? "SAVE QSO" : "LOG QSO")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.parsedCallsign.isEmpty)
        .sensoryFeedback(.success, trigger: viewModel.saveCount)
    }

    // MARK: - Private

    private func submitQSO() {
        guard !viewModel.parsedCallsign.isEmpty else { return }
        Task {
            await viewModel.saveQSO()
            if let saved = viewModel.lastSavedQSO {
                editingQSO = nil
                onSave(saved)
            }
            focusedField = .callsign
        }
    }
}
