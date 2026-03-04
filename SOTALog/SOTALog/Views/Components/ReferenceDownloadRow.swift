import SwiftUI

struct ReferenceDownloadRow: View {
    let title: String
    let metadataKey: String
    let unitName: String
    let database: AppDatabase
    let download: (ReferenceRepository, _ onProgress: @escaping (String) -> Void) async throws -> Int
    var onComplete: (() -> Void)?

    @State private var metadata: ReferenceMetadata?
    @State private var isLoading = false
    @State private var progress: String?
    @State private var errorMessage: String?

    private var refRepo: ReferenceRepository {
        ReferenceRepository(database: database)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                if let progress {
                    Text(progress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let meta = metadata {
                    Text("\(meta.recordCount ?? 0) \(unitName) • \(meta.lastRefreshed?.shortDateDisplay ?? "Never")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not downloaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            metadata = try? await refRepo.fetchMetadata(key: metadataKey)
        }

        if let error = errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(Color.appRed)
        }
    }

    private func refresh() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            progress = nil
        }

        do {
            let count = try await download(refRepo) { message in
                progress = message
            }
            try await refRepo.saveMetadata(ReferenceMetadata(
                key: metadataKey,
                lastRefreshed: Date(),
                recordCount: count
            ))
            metadata = try? await refRepo.fetchMetadata(key: metadataKey)
            onComplete?()
        } catch {
            errorMessage = "\(title) refresh failed: \(error.localizedDescription)"
        }
    }
}

extension ReferenceDownloadRow {
    static func potaParks(
        database: AppDatabase,
        userLatitude: Double? = nil,
        userLongitude: Double? = nil,
        onComplete: (() -> Void)? = nil
    ) -> ReferenceDownloadRow {
        ReferenceDownloadRow(
            title: "POTA Parks",
            metadataKey: "potaParks",
            unitName: "parks",
            database: database,
            download: { refRepo, onProgress in
                onProgress("Downloading parks...")
                let parks = try await POTAParkService.fetchAllParks()
                onProgress("Importing \(parks.count) parks...")
                try await refRepo.deleteAllParks()
                try await refRepo.importParks(parks)

                // Enrich with coordinates from POTA API
                do {
                    try await POTALocationService.enrichParks(
                        refRepo: refRepo,
                        userLatitude: userLatitude,
                        userLongitude: userLongitude,
                        onProgress: onProgress
                    )
                } catch {
                    // Partial enrichment is fine — keep whatever parks were imported
                }

                return parks.count
            },
            onComplete: onComplete
        )
    }

    static func sotaSummits(database: AppDatabase, onComplete: (() -> Void)? = nil) -> ReferenceDownloadRow {
        ReferenceDownloadRow(
            title: "SOTA Summits",
            metadataKey: "sotaSummits",
            unitName: "summits",
            database: database,
            download: { refRepo, onProgress in
                onProgress("Downloading summits...")
                let summits = try await SOTASummitService.fetchSummits()
                onProgress("Importing \(summits.count) summits...")
                try await refRepo.deleteAllSummits()
                try await refRepo.importSummits(summits)
                return summits.count
            },
            onComplete: onComplete
        )
    }
}
