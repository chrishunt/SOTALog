import Combine
import SwiftUI

struct QSOEntryView: View {
    let database: AppDatabase
    let log: Log
    @Binding var editingQSO: QSO?
    @Binding var pendingSpot: Spot?
    let onSave: (QSO) -> Void

    @Environment(SpotsViewModel.self) private var spotsViewModel
    @Environment(SOTACatService.self) private var sotaCatService
    @State private var viewModel: QSOEntryViewModel
    @State private var qrzService: QRZLookupService
    @State private var cwMacros: [CWMacro] = []
    @State private var editingMacro: CWMacro?
    @State private var pressedMacroPosition: Int?
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
            if viewModel.isEditing {
                editingBanner
            }

            metadataStrip

            if sotaCatService.isConnected && viewModel.mode == "CW" {
                cwMacroRow
            }

            callsignRow

            #if os(iOS)
            if focusedField == .callsign {
                NumberKeyRow { char in
                    viewModel.entryText.append(char)
                }
                .padding(.horizontal, -13)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.15), value: focusedField)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.appSurface)
        .overlay(alignment: .top) { Divider() }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { notification in
            guard let textField = notification.object as? UITextField else { return }
            DispatchQueue.main.async {
                if focusedField == .callsign {
                    let end = textField.endOfDocument
                    textField.selectedTextRange = textField.textRange(from: end, to: end)
                } else {
                    textField.selectAll(nil)
                }
            }
        }
        #endif
        .task {
            await loadMacros()
        }
        .sheet(item: $editingMacro) { macro in
            CWMacroEditView(
                macro: macro,
                expandTemplate: { viewModel.previewExpandTemplate($0) },
                onSave: { updated in
                    saveMacro(updated)
                },
                onReset: {
                    resetMacro(position: macro.position)
                }
            )
        }
        .onAppear {
            viewModel.spotLookup = spotsViewModel.spotForCallsign
            viewModel.qrzLookup = qrzService
            viewModel.sotaCatService = sotaCatService
            if sotaCatService.isConnected {
                viewModel.updateFromRadio(frequencyMHz: sotaCatService.radioFrequency)
                viewModel.updateModeFromRadio(sotaCatService.radioMode)
            }
            focusedField = .callsign
        }
        .onChange(of: sotaCatService.radioFrequency) { _, newValue in
            viewModel.updateFromRadio(frequencyMHz: newValue)
        }
        .onChange(of: sotaCatService.radioMode) { _, newValue in
            viewModel.updateModeFromRadio(newValue)
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
    }

    // MARK: - Metadata Strip

    private var metadataStrip: some View {
        MetadataStrip(
            rstSent: $viewModel.rstSent,
            rstReceived: $viewModel.rstReceived,
            frequencyText: $viewModel.frequencyText,
            mode: $viewModel.mode,
            name: $viewModel.name,
            qth: $viewModel.qth,
            potaRefInput: $viewModel.potaRefInput,
            potaRefFormatted: viewModel.potaRefFormatted,
            potaRefValid: viewModel.potaRefValid,
            sotaRefInput: $viewModel.sotaRefInput,
            sotaRefFormatted: viewModel.sotaRefFormatted,
            sotaRefValid: viewModel.sotaRefValid,
            onManualOverride: { viewModel.markManualOverride($0) },
            onModeToggle: { viewModel.toggleMode() },
            onPOTAChanged: { viewModel.validatePOTARef() },
            onSOTAChanged: { viewModel.validateSOTARef() },
            isRadioConnected: sotaCatService.isConnected,
            onFrequencyChanged: { viewModel.frequencyChanged() },
            onFrequencyCommitted: { viewModel.pushFrequencyToRadio() },
            onSubmit: { focusedField = .callsign }
        )
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

    // MARK: - CW Macro Row

    private var cwMacroRow: some View {
        HStack(spacing: 8) {
            ForEach(cwMacros) { macro in
                let expanded = viewModel.expandTemplate(macro.template)
                if !expanded.isEmpty {
                    cwMacroButton(macro: macro)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.keyerSendCount)
    }

    private func cwMacroButton(macro: CWMacro) -> some View {
        Text(macro.label)
            .font(.appMacroButton)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Color.appOrange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.appOrange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .scaleEffect(pressedMacroPosition == macro.position ? 0.93 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: pressedMacroPosition)
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
                viewModel.sendCWMacro(macro.template)
            }
            .onLongPressGesture(minimumDuration: 0.5, pressing: { isPressing in
                pressedMacroPosition = isPressing ? macro.position : nil
            }, perform: {
                editingMacro = macro
            })
    }

    // MARK: - Callsign Row

    private var callsignRow: some View {
        CallsignField(
            text: $viewModel.entryText,
            timesWorked: viewModel.timesWorked,
            workedToday: viewModel.workedToday,
            isDupe: viewModel.isDupe,
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

    // MARK: - Private

    private func loadMacros() async {
        let repo = CWMacroRepository(database: database)
        cwMacros = (try? await repo.fetchAll()) ?? []
    }

    private func saveMacro(_ macro: CWMacro) {
        let repo = CWMacroRepository(database: database)
        Task {
            var m = macro
            try? await repo.save(&m)
            await loadMacros()
        }
    }

    private func resetMacro(position: Int) {
        let repo = CWMacroRepository(database: database)
        Task {
            try? await repo.resetOne(position: position)
            await loadMacros()
        }
    }

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
