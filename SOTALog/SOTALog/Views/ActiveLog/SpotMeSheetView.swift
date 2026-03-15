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
                Text("Post your spot via [SOTAmāt](https://sotamat.com/sms-services/) SMS.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                .disabled(spotMessage == nil || !canSendText)

                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle("Spot Me")
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
