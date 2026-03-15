import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

struct SpotMeSheetView: View {
    let log: Log
    let frequencyMHz: String
    let mode: String

    @Environment(\.dismiss) private var dismiss
    @State private var comment: String = ""
    @State private var showingMessageCompose = false

    private var spotMessage: String? {
        SOTAmatService.spotMessage(
            log: log,
            frequencyMHz: frequencyMHz,
            mode: mode,
            comment: comment.isEmpty ? nil : comment
        )
    }

    private var canSendText: Bool {
        #if canImport(MessageUI)
        return MFMessageComposeViewController.canSendText()
        #else
        return false
        #endif
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(spotMessage ?? "")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.appSurfaceRaised, in: RoundedRectangle(cornerRadius: 8))

                TextField("e.g. QRT, Running 5W", text: $comment)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .submitLabel(.done)

                Button {
                    showingMessageCompose = true
                } label: {
                    Label("Send via SMS", systemImage: "message.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appOrange)
                .disabled(spotMessage == nil || !canSendText)

                HStack(spacing: 4) {
                    Text("Via SOTAmāt")
                        .font(.caption)
                        .foregroundStyle(Color.appTextTertiary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Color.appTextTertiary)
                    Link("Setup SMS", destination: SOTAmatService.setupURL)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            #if os(iOS)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
        .presentationDetents([.medium])
        #if canImport(MessageUI)
        .sheet(isPresented: $showingMessageCompose) {
            MessageComposeView(
                recipients: [SOTAmatService.phoneNumber],
                body: spotMessage ?? "",
                onDismiss: { showingMessageCompose = false }
            )
            .ignoresSafeArea()
        }
        #endif
    }
}
