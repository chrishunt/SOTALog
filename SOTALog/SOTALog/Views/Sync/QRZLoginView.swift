import SwiftUI

struct QRZLoginView: View {
    @Bindable var viewModel: QRZSyncViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var username = ""
    @State private var password = ""
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .autocorrectionDisabled()
                    if didSave {
                        credentialStatus(result: viewModel.apiKeyTestResult, label: "API key")
                    }
                } header: {
                    Text("Logbook Sync")
                } footer: {
                    Link("Find your API key on QRZ.com",
                         destination: URL(string: "https://www.qrz.com/docs/logbook30/api")!)
                }

                Section("Callsign Lookup") {
                    TextField("Callsign", text: $username)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                    if didSave {
                        credentialStatus(result: viewModel.xmlLoginTestResult, label: "Login")
                    }
                }
            }
            .navigationTitle("QRZ Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        didSave = true
                        Task {
                            await viewModel.saveCredentials(
                                apiKey: apiKey,
                                username: username,
                                password: password
                            )
                            if viewModel.allTestsPassed {
                                dismiss()
                            }
                        }
                    }
                    .bold()
                    .disabled(viewModel.isTestingCredentials)
                }
            }
            .onAppear {
                apiKey = KeychainService.load(key: .qrzAPIKey) ?? ""
                username = KeychainService.load(key: .qrzUsername) ?? ""
            }
        }
    }

    @ViewBuilder
    private func credentialStatus(result: QRZSyncViewModel.CredentialTestResult?, label: String) -> some View {
        if viewModel.isTestingCredentials && result == nil {
            HStack(spacing: 8) {
                ProgressView()
                Text("Testing \(label.lowercased())...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let result {
            switch result {
            case .success:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appGreen)
                    Text("\(label) verified")
                        .font(.caption)
                        .foregroundStyle(Color.appGreen)
                }
            case .failure(let message):
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appRed)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.appRed)
                }
            }
        }
    }
}
