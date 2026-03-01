import SwiftUI

struct ReferenceManagerView: View {
    let database: AppDatabase
    @State private var potaMetadata: ReferenceMetadata?
    @State private var sotaMetadata: ReferenceMetadata?
    @State private var isLoadingPOTA = false
    @State private var isLoadingSOTA = false
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
                    if let meta = potaMetadata {
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
                    if let meta = sotaMetadata {
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
                    .foregroundStyle(.red)
            }
        }
        .task {
            potaMetadata = try? await refRepo.fetchMetadata(key: "potaParks")
            sotaMetadata = try? await refRepo.fetchMetadata(key: "sotaSummits")
        }
    }

    private func refreshPOTA() async {
        isLoadingPOTA = true
        defer { isLoadingPOTA = false }

        do {
            let locations = try await POTAParkService.fetchLocations()
            var allParks: [POTAPark] = []

            for location in locations {
                let parks = try await POTAParkService.fetchParks(locationCode: location.locationCode)
                allParks.append(contentsOf: parks)
            }

            try await refRepo.deleteAllParks()
            try await refRepo.importParks(allParks)
            try await refRepo.saveMetadata(ReferenceMetadata(
                key: "potaParks",
                lastRefreshed: Date(),
                recordCount: allParks.count
            ))
            potaMetadata = try? await refRepo.fetchMetadata(key: "potaParks")
            errorMessage = nil
        } catch {
            errorMessage = "POTA refresh failed: \(error.localizedDescription)"
        }
    }

    private func refreshSOTA() async {
        isLoadingSOTA = true
        defer { isLoadingSOTA = false }

        do {
            let summits = try await SOTASummitService.fetchSummits()
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
