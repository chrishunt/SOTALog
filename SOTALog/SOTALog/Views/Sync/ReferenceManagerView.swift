import SwiftUI

struct ReferenceManagerView: View {
    let database: AppDatabase
    @State private var potaMetadata: ReferenceMetadata?
    @State private var sotaMetadata: ReferenceMetadata?
    @State private var isLoadingPOTA = false
    @State private var isLoadingSOTA = false
    @State private var potaProgress: String?
    @State private var sotaProgress: String?
    @State private var errorMessage: String?

    private var refRepo: ReferenceRepository {
        ReferenceRepository(database: database)
    }

    var body: some View {
        Group {
            // POTA Parks
            HStack {
                VStack(alignment: .leading) {
                    Text("POTA Parks")
                        .font(.subheadline)
                    if let progress = potaProgress {
                        Text(progress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let meta = potaMetadata {
                        Text("\(meta.recordCount ?? 0) parks • \(meta.lastRefreshed?.shortDateDisplay ?? "Never")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not downloaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isLoadingPOTA {
                    ProgressView()
                } else {
                    Button {
                        Task { await refreshPOTA() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }

            // SOTA Summits
            HStack {
                VStack(alignment: .leading) {
                    Text("SOTA Summits")
                        .font(.subheadline)
                    if let progress = sotaProgress {
                        Text(progress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let meta = sotaMetadata {
                        Text("\(meta.recordCount ?? 0) summits • \(meta.lastRefreshed?.shortDateDisplay ?? "Never")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not downloaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isLoadingSOTA {
                    ProgressView()
                } else {
                    Button {
                        Task { await refreshSOTA() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.appRed)
            }
        }
        .task {
            potaMetadata = try? await refRepo.fetchMetadata(key: "potaParks")
            sotaMetadata = try? await refRepo.fetchMetadata(key: "sotaSummits")
        }
    }

    private func refreshPOTA() async {
        isLoadingPOTA = true
        potaProgress = "Downloading parks..."
        defer {
            isLoadingPOTA = false
            potaProgress = nil
        }

        do {
            let parks = try await POTAParkService.fetchAllParks()
            potaProgress = "Importing \(parks.count) parks..."
            try await refRepo.deleteAllParks()
            try await refRepo.importParks(parks)
            try await refRepo.saveMetadata(ReferenceMetadata(
                key: "potaParks",
                lastRefreshed: Date(),
                recordCount: parks.count
            ))
            potaMetadata = try? await refRepo.fetchMetadata(key: "potaParks")
            errorMessage = nil
        } catch {
            errorMessage = "POTA refresh failed: \(error.localizedDescription)"
        }
    }

    private func refreshSOTA() async {
        isLoadingSOTA = true
        sotaProgress = "Downloading summits..."
        defer {
            isLoadingSOTA = false
            sotaProgress = nil
        }

        do {
            let summits = try await SOTASummitService.fetchSummits()
            sotaProgress = "Importing \(summits.count) summits..."
            try await refRepo.deleteAllSummits()
            try await refRepo.importSummits(summits)
            try await refRepo.saveMetadata(ReferenceMetadata(
                key: "sotaSummits",
                lastRefreshed: Date(),
                recordCount: summits.count
            ))
            sotaMetadata = try? await refRepo.fetchMetadata(key: "sotaSummits")
            errorMessage = nil
        } catch {
            errorMessage = "SOTA refresh failed: \(error.localizedDescription)"
        }
    }
}
