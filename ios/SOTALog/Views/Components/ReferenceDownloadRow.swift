import SwiftUI
import HamCore

struct ReferenceDownloadRow: View {
    let title: String
    let metadataKey: String
    let unitName: String
    let database: LogbookDatabase
    let download: (ReferenceRepository, _ onProgress: @escaping @Sendable (String) -> Void) async throws -> Int
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
                        .font(.appLabel)
                        .foregroundStyle(Color.appTextSecondary)
                } else if let meta = metadata {
                    Text("\(meta.recordCount ?? 0) \(unitName) • \(meta.lastRefreshed?.shortDateDisplay ?? "Never")")
                        .font(.appLabel)
                        .foregroundStyle(Color.appTextSecondary)
                } else {
                    Text("Not downloaded")
                        .font(.appLabel)
                        .foregroundStyle(Color.appTextSecondary)
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
                .font(.appLabel)
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
                // HamCore reports progress from background tasks; SwiftUI state lives on the main actor.
                Task { @MainActor in progress = message }
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
        database: LogbookDatabase,
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
                let parks = try await POTAParkService(client: .sotaLog).fetchAllParks()
                onProgress("Importing \(parks.count) parks...")
                try await refRepo.deleteAllParks()
                try await refRepo.importParks(parks)

                // Enrich with coordinates from POTA API
                do {
                    try await POTALocationService(client: .sotaLog).enrichParks(
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

    static func sotaSummits(database: LogbookDatabase, onComplete: (() -> Void)? = nil) -> ReferenceDownloadRow {
        ReferenceDownloadRow(
            title: "SOTA Summits",
            metadataKey: "sotaSummits",
            unitName: "summits",
            database: database,
            download: { refRepo, onProgress in
                onProgress("Downloading summits...")
                let summits = try await SOTASummitService(client: .sotaLog).fetchSummits()
                onProgress("Importing \(summits.count) summits...")
                try await refRepo.deleteAllSummits()
                try await refRepo.importSummits(summits)
                return summits.count
            },
            onComplete: onComplete
        )
    }
}
