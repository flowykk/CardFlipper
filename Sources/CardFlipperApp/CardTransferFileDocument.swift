import Core
import SwiftUI
import UniformTypeIdentifiers

struct CardTransferFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var transfer: CardTransferDocument

    init(transfer: CardTransferDocument) {
        self.transfer = transfer
    }

    init(configuration: ReadConfiguration) throws {
        transfer = try JSONDecoder().decode(CardTransferDocument.self, from: configuration.file.regularFileContents ?? Data())
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(transfer))
    }
}
