import SwiftUI

struct LogbookSyncSignInView: View {
    @Bindable var viewModel: QRZSyncViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                    if didSave {
                        CredentialStatusView(
                            isTesting: viewModel.isTestingCredentials,
                            result: viewModel.apiKeyTestResult,
                            label: "API key"
                        )
                    }
                } footer: {
                    Link("Find your API key at QRZ.com",
                         destination: URL(string: "https://www.qrz.com/docs/logbook30/api")!)
                }
            }
            .navigationTitle("Logbook Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        didSave = true
                        Task {
                            await viewModel.saveAPIKey(apiKey)
                            if viewModel.apiKeyTestPassed {
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
            }
        }
    }

}

struct CallsignLookupSignInView: View {
    @Bindable var viewModel: QRZSyncViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Callsign", text: $username)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.none)
                    if didSave {
                        CredentialStatusView(
                            isTesting: viewModel.isTestingCredentials,
                            result: viewModel.xmlLoginTestResult,
                            label: "Credentials"
                        )
                    }
                }
            }
            .navigationTitle("Callsign Lookup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        didSave = true
                        Task {
                            await viewModel.saveCallsignCredentials(
                                username: username,
                                password: password
                            )
                            if viewModel.callsignTestPassed {
                                dismiss()
                            }
                        }
                    }
                    .bold()
                    .disabled(viewModel.isTestingCredentials)
                }
            }
            .onAppear {
                username = KeychainService.load(key: .qrzUsername) ?? ""
            }
        }
    }
}

// MARK: - Shared credential status indicator

private struct CredentialStatusView: View {
    let isTesting: Bool
    let result: QRZSyncViewModel.CredentialTestResult?
    let label: String

    var body: some View {
        if isTesting && result == nil {
            HStack(spacing: 8) {
                ProgressView()
                Text("Testing \(label.lowercased())...")
                    .font(.appLabel)
                    .foregroundStyle(Color.appTextSecondary)
            }
        } else if let result {
            switch result {
            case .success:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appGreen)
                    Text("\(label) verified")
                        .font(.appLabel)
                        .foregroundStyle(Color.appGreen)
                }
            case .failure(let message):
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appRed)
                    Text(message)
                        .font(.appLabel)
                        .foregroundStyle(Color.appRed)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
