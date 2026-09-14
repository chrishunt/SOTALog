import SwiftUI
import HamCore

struct ReferenceManagerView: View {
    let database: AppDatabase

    var body: some View {
        Group {
            ReferenceDownloadRow.potaParks(database: database)
            ReferenceDownloadRow.sotaSummits(database: database)
        }
    }
}
