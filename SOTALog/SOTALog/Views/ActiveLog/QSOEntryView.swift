import Combine
import SwiftUI

struct QSOEntryView: View {
    let database: AppDatabase
    let log: Log
    @Binding var editingQSO: QSO?
    @Binding var pendingSpot: Spot?
    let onSave: (QSO) -> Void

    @Environment(SpotsViewModel.self) private var spotsViewModel
    @State private var viewModel: QSOEntryViewModel
    @State private var qrzService: QRZLookupService
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
        let historyRepo = CallsignHistoryRepository(database: database)
        self._qrzService = State(initialValue: QRZLookupService(historyRepo: historyRepo))
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
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { notification in
            if let textField = notification.object as? UITextField {
                DispatchQueue.main.async {
                    textField.selectAll(nil)
                }
            }
        }
        #endif
        .onAppear {
            viewModel.spotLookup = spotsViewModel.spotForCallsign
            viewModel.qrzLookup = qrzService
            focusedField = .callsign
        }
        .onChange(of: editingQSO) { _, newValue in
            if let qso = newValue {
                viewModel.loadForEditing(qso)
                focusedField = .callsign
            }
        }
        .onChange(of: pendingSpot, initial: true) { _, newValue in
            if let spot = newValue {
                viewModel.prefillFromSpot(spot)
                pendingSpot = nil
                focusedField = .callsign
            }
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField == .callsign {
                    HStack(spacing: 6) {
                        ForEach(["1","2","3","4","5","6","7","8","9","0","/"], id: \.self) { char in
                            Button(char) {
                                viewModel.entryText.append(char)
                            }
                            .font(.callout.monospacedDigit())
                            .frame(minWidth: 28, minHeight: 36)
                        }
                    }
                }
            }
        }
        #endif
    }

    // MARK: - Editing Banner

    private var editingBanner: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(Color.appOrange)
            Text("Editing: \(viewModel.parsedCallsign)")
                .font(.subheadline.bold())
                .foregroundStyle(Color.appOrange)
            Spacer()
            Button("Cancel") {
                viewModel.cancelEditing()
                editingQSO = nil
                focusedField = .callsign
            }
            .font(.subheadline)
            .foregroundStyle(Color.appOrange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.appOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Callsign Row

    private var callsignRow: some View {
        CallsignField(
            text: $viewModel.entryText,
            timesWorked: viewModel.timesWorked,
            sanitizer: { $0.sanitizedOmnifield }
        )
        .focused($focusedField, equals: .callsign)
        .submitLabel(.send)
        .onSubmit {
            submitQSO()
        }
        .onChange(of: viewModel.entryText) { _, _ in
            viewModel.parseEntry()
            viewModel.callsignChanged()
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
                    .submitLabel(.send)
                    .onSubmit { submitQSO() }
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
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .name)
                    .submitLabel(.send)
                    .onSubmit { submitQSO() }
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("QTH")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("QTH", text: $viewModel.qth)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .qth)
                    .submitLabel(.send)
                    .onSubmit { submitQSO() }
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.qth) { _, _ in
                        if focusedField == .qth {
                            viewModel.markManualOverride("qth")
                        }
                    }
            }
            .frame(width: 80)
        }
    }

    // MARK: - P2P

    private var p2pRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Park to Park")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("Park (e.g. US4431)", text: $viewModel.potaRefInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .potaRef)
                    .submitLabel(.send)
                    .onSubmit { submitQSO() }
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
                        .foregroundStyle(Color.appGreen)
                }
            }
        }
    }

    // MARK: - S2S

    private var s2sRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Summit to Summit")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("Summit (e.g. W4CCM001)", text: $viewModel.sotaRefInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .sotaRef)
                    .submitLabel(.send)
                    .onSubmit { submitQSO() }
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
                        .foregroundStyle(Color.appGreen)
                }
            }
        }
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            submitQSO()
        } label: {
            Text(viewModel.isEditing ? "SAVE QSO" : "LOG QSO")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.parsedCallsign.isEmpty)
        .sensoryFeedback(.success, trigger: viewModel.saveCount)
        .accessibilityLabel(viewModel.isEditing ? "Save QSO" : "Log QSO")
        .accessibilityHint("Saves the current contact")
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
