import CryptoKit
import Foundation

struct ImportedArtwork: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let importedAt: Date
    var edits: [ImageEdit] = []
}

extension Notification.Name {
    static let coStudioImageLibraryDidRestore = Self("CoStudioImageLibraryDidRestore")
}

enum ImageLibrary {
    private static let mutations = NSLock()
    #if DEBUG
    private static let uiTestDirectory = URL.temporaryDirectory.appending(
        path: "CoStudio-UI-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    #endif

    struct Catalog: Codable {
        var version = 1
        var images: [ImportedArtwork] = []
    }

    static var directory: URL {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return uiTestDirectory }
        #endif
        return URL.applicationSupportDirectory.appending(path: "CoStudio/Images", directoryHint: .isDirectory)
    }

    static func load(in directory: URL = directory) throws -> Catalog {
        let file = directory.appending(path: "catalog.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return Catalog() }
        let properties = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink != true else {
            throw ImageStudioError.invalidCatalog
        }
        guard let result = try? JSONDecoder().decode(Catalog.self, from: Data(contentsOf: file)),
              result.version == 1, result.images.allSatisfy({ validID($0.id) }),
              Set(result.images.map(\.id)).count == result.images.count else {
            throw ImageStudioError.invalidCatalog
        }
        return result
    }

    static func importImage(_ file: URL, in directory: URL = directory) throws -> ImportedArtwork {
        let accessed = file.startAccessingSecurityScopedResource()
        defer { if accessed { file.stopAccessingSecurityScopedResource() } }
        let resolved = file.resolvingSymlinksInPath()
        _ = try ImagePipeline.load(resolved)
        let id = try contentHash(resolved)
        let name = file.deletingPathExtension().lastPathComponent
        return try mutations.withLock {
            try storeImport(resolved, id: id, name: name, in: directory)
        }
    }

    private static func storeImport(_ file: URL, id: String, name: String, in directory: URL) throws -> ImportedArtwork {
        var catalog = try load(in: directory)
        let destination = try originalURL(id, in: directory)
        if let existing = catalog.images.first(where: { $0.id == id }) {
            if !FileManager.default.fileExists(atPath: destination.path) { try copy(file, to: destination) }
            return existing
        }
        let artwork = ImportedArtwork(id: id, name: name, importedAt: .now)
        let shouldCopy = !FileManager.default.fileExists(atPath: destination.path)
        if shouldCopy { try copy(file, to: destination) }
        catalog.images.insert(artwork, at: 0)
        do {
            try write(catalog, in: directory)
        } catch {
            if shouldCopy { try? FileManager.default.removeItem(at: destination) }
            throw error
        }
        return artwork
    }

    static func original(_ artwork: ImportedArtwork, in directory: URL = directory) throws -> URL {
        let file = try originalURL(artwork.id, in: directory)
        let properties = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard properties?.isRegularFile == true, properties?.isSymbolicLink != true else {
            throw ImageStudioError.missingOriginal
        }
        return file
    }

    static func update(
        _ artwork: ImportedArtwork, replacing edits: [ImageEdit]? = nil, in directory: URL = directory
    ) throws {
        try mutations.withLock {
            var catalog = try load(in: directory)
            guard let index = catalog.images.firstIndex(where: { $0.id == artwork.id }) else {
                throw ImageStudioError.missingOriginal
            }
            if let edits, edits != catalog.images[index].edits { throw ImageStudioError.editsChanged }
            catalog.images[index] = artwork
            try write(catalog, in: directory)
        }
    }

    static func remove(_ artwork: ImportedArtwork, in directory: URL = directory) throws {
        try mutations.withLock {
            var catalog = try load(in: directory)
            catalog.images.removeAll { $0.id == artwork.id }
            let file = try originalURL(artwork.id, in: directory)
            let manager = FileManager.default
            guard manager.fileExists(atPath: file.path) else {
                try write(catalog, in: directory)
                return
            }
            let staged = file.deletingLastPathComponent().appending(path: ".remove-" + UUID().uuidString)
            try manager.moveItem(at: file, to: staged)
            do {
                try write(catalog, in: directory)
            } catch {
                try manager.moveItem(at: staged, to: file)
                throw error
            }
            try? manager.removeItem(at: staged)
        }
    }

    static func merge(from archive: URL) throws {
        try merge(from: archive, into: directory)
    }

    static func merge(from archive: URL, into directory: URL) throws {
        let storage = archive.appending(path: "originals", directoryHint: .isDirectory)
        let properties = try archive.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard properties.isDirectory == true, properties.isSymbolicLink != true else {
            throw ImageStudioError.invalidCatalog
        }
        let incoming = try load(in: archive)
        guard !incoming.images.isEmpty else { return }
        let storageProperties = try storage.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard storageProperties.isDirectory == true, storageProperties.isSymbolicLink != true else {
            throw ImageStudioError.invalidCatalog
        }
        try mutations.withLock {
            try storeMerged(incoming, from: archive, into: directory)
        }
    }

    private static func storeMerged(_ incoming: Catalog, from archive: URL, into directory: URL) throws {
        var local = try load(in: directory)
        let localIDs = Set(local.images.map(\.id))
        var copies: [URL] = []
        do {
            for artwork in incoming.images {
                let destination = try originalURL(artwork.id, in: directory)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    let file = try original(artwork, in: archive)
                    guard try contentHash(file) == artwork.id else { throw ImageStudioError.invalidCatalog }
                    try copy(file, to: destination)
                    copies.append(destination)
                }
                if !localIDs.contains(artwork.id) { local.images.append(artwork) }
            }
            local.images.sort { $0.importedAt > $1.importedAt }
            try write(local, in: directory)
        } catch {
            for file in copies { try? FileManager.default.removeItem(at: file) }
            throw error
        }
    }

    private static func validID(_ id: String) -> Bool {
        id.utf8.count == 64 && id.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func originalURL(_ id: String, in directory: URL) throws -> URL {
        guard validID(id) else { throw ImageStudioError.invalidCatalog }
        return directory.appending(path: "originals", directoryHint: .isDirectory).appending(path: id)
    }

    private static func write(_ catalog: Catalog, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(catalog)
        try data.write(to: directory.appending(path: "catalog.json"), options: .atomic)
    }

    private static func copy(_ file: URL, to destination: URL) throws {
        let manager = FileManager.default
        let parent = destination.deletingLastPathComponent()
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let temporary = parent.appending(path: ".import-" + UUID().uuidString)
        defer { try? manager.removeItem(at: temporary) }
        try manager.copyItem(at: file, to: temporary)
        try manager.moveItem(at: temporary, to: destination)
    }

    private static func contentHash(_ file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var digest = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            digest.update(data: chunk)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
