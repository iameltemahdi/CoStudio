import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct CreativeExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .plainText, .json, .svg] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    static let studioLibraryBackup = UTType(exportedAs: "org.costudio.library-backup", conformingTo: .package)
}

struct LibraryBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.studioLibraryBackup]
    var libraryData: Data
    var imagesDirectory: URL?

    init(libraryData: Data = Data(), imagesDirectory: URL? = nil) {
        self.libraryData = libraryData
        self.imagesDirectory = imagesDirectory
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.fileWrappers?["library.json"]?.regularFileContents else {
            throw LibraryBackupError.invalidContents
        }
        self.libraryData = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try packageWrapper()
    }

    func packageWrapper() throws -> FileWrapper {
        var files = ["library.json": FileWrapper(regularFileWithContents: libraryData)]
        if let imagesDirectory {
            files["Images"] = try FileWrapper(url: imagesDirectory, options: [])
        }
        return FileWrapper(directoryWithFileWrappers: files)
    }

    static func readPackage(at url: URL) throws -> LibrarySnapshot {
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer { if hasScopedAccess { url.stopAccessingSecurityScopedResource() } }
        let catalogURL = url.appending(path: "library.json")
        let properties = try catalogURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink != true else {
            throw LibraryBackupError.invalidContents
        }
        let snapshot = try LibrarySnapshot.decode(Data(contentsOf: catalogURL))
        let imagesURL = url.appending(path: "Images", directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: imagesURL.path) {
            let properties = try imagesURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard properties.isDirectory == true, properties.isSymbolicLink != true else {
                throw LibraryBackupError.invalidContents
            }
            try ImageLibrary.merge(from: imagesURL)
        }
        return snapshot
    }

    @MainActor
    static func restore(_ snapshot: LibrarySnapshot, into context: ModelContext) throws {
        try snapshot.merge(into: context)
        NotificationCenter.default.post(name: .coStudioImageLibraryDidRestore, object: nil)
    }
}
