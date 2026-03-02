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
        VStack(spacing: 8) {
            // Editing banner
            if viewModel.isEditing {
                editingBanner
            }

            // RST + Frequency + Name + QTH row
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

            // Callsign omnibox — dominant element, directly above keyboard
            callsignRow
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Material.bar)
        .overlay(alignment: .top) { Divider() }
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
        .sensoryFeedback(.success, trigger: viewModel.saveCount)
        .onChange(of: viewModel.entryText) { _, _ in
            viewModel.parseEntry()
            viewModel.callsignChanged()
        }
    }

    // MARK: - RST + Frequency

    private var rstFrequencyRow: some View {
        HStack(spacing: 8) {
            RSTField(value: $viewModel.rstSent)
                .onChange(of: focusedField) { _, newValue in
                    if newValue == .callsign { return }
                }

            RSTField(value: $viewModel.rstReceived)

            TextField("14.060", text: $viewModel.frequencyText)
                .font(.callout.monospacedDigit())
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

    // MARK: - Name + QTH

    private var nameQTHRow: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $viewModel.name)
                .font(.callout)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .name)
                .submitLabel(.send)
                .onSubmit { submitQSO() }
                .textFieldStyle(.roundedBorder)

            TextField("QTH", text: $viewModel.qth)
                .font(.callout)
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
                .frame(width: 80)
        }
    }

    // MARK: - P2P

    private var p2pRow: some View {
        HStack {
            Text("P2P")
                .font(.callout.bold())
                .foregroundStyle(.secondary)

            TextField("Park (e.g. US4431)", text: $viewModel.potaRefInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .potaRef)
                .submitLabel(.send)
                .onSubmit { submitQSO() }
                .textFieldStyle(.roundedBorder)
                .font(.callout.monospaced())
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

            if viewModel.potaRefValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.appGreen)
                    .font(.callout)
            }

            if let name = viewModel.potaRefName {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - S2S

    private var s2sRow: some View {
        HStack {
            Text("S2S")
                .font(.callout.bold())
                .foregroundStyle(.secondary)

            TextField("Summit (e.g. W4CCM001)", text: $viewModel.sotaRefInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .sotaRef)
                .submitLabel(.send)
                .onSubmit { submitQSO() }
                .textFieldStyle(.roundedBorder)
                .font(.callout.monospaced())
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
                    .font(.callout)
            }
        }
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
