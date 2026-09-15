import CoreTransferable
import UniformTypeIdentifiers
import HamCore

extension UTType {
    /// The `.adi` type this app exports, declared in its Info.plist.
    static var adif: UTType { UTType(exportedAs: "com.sotalog.adi") }
}

/// Lets an ADIF document from HamCore go straight into a ShareLink.
extension ADIFFile: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .adif) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(file.filename)
            try file.content.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
