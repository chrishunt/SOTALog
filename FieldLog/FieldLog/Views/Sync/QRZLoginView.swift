import SwiftUI

struct QRZLoginView: View {
    @Bindable var viewModel: QRZSyncViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter your QRZ API key for logbook sync, and your username/password for callsign lookups.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Logbook API Key") {
                    SecureField("QRZ API Key", text: $apiKey)
                        .autocorrectionDisabled()
                }

                Section("XML Lookup Credentials") {
                    TextField("QRZ Username", text: $username)
                        .autocorrectionDisabled()
                    SecureField("QRZ Password", text: $password)
                }
            }
            .navigationTitle("QRZ Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveCredentials(
                            apiKey: apiKey,
                            username: username,
                            password: password
                        )
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                apiKey = KeychainService.load(key: .qrzAPIKey) ?? ""
                username = KeychainService.load(key: .qrzUsername) ?? ""
            }
        }
    }
}
