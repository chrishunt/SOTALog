import SwiftUI
import HamCore

struct ReferenceManagerView: View {
    let database: LogbookDatabase

    var body: some View {
        Group {
            ReferenceDownloadRow.potaParks(database: database)
            ReferenceDownloadRow.sotaSummits(database: database)
        }
    }
}
