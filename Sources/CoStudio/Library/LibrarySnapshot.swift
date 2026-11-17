import Foundation
import SwiftData

struct LibrarySnapshot: Codable, Sendable {
    struct Project: Codable, Sendable {
        let id: UUID
        let name: String
        let favorite: Bool
        let order: Int
    }

    struct Collection: Codable, Sendable {
        let id: UUID
        let name: String
        let projectID: UUID?
        let favorite: Bool
        let order: Int
    }

    struct Palette: Codable, Sendable {
        let id: UUID
        let name: String
        let hexColors: [String]
        let collectionID: UUID?
        let favorite: Bool
        let order: Int
        let updatedAt: Date
    }

    let version: Int
    let projects: [Project]
    let collections: [Collection]
    let palettes: [Palette]

    init(projects: [StudioProject], collections: [StudioCollection], palettes: [StudioPalette]) {
        self.version = 1
        self.projects = projects.map {
            Project(id: $0.id, name: $0.name, favorite: $0.favorite, order: $0.order)
        }
        self.collections = collections.map {
            Collection(id: $0.id, name: $0.name, projectID: $0.projectID, favorite: $0.favorite, order: $0.order)
        }
        self.palettes = palettes.map {
            Palette(
                id: $0.id, name: $0.name, hexColors: $0.hexColors, collectionID: $0.collectionID,
                favorite: $0.favorite, order: $0.order, updatedAt: $0.updatedAt
            )
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(Self.self, from: data)
        try snapshot.validate()
        return snapshot
    }

    private func validate() throws {
        guard version == 1 else { throw LibraryBackupError.unsupportedVersion }
        let projectIDs = Set(projects.map(\.id))
        let collectionIDs = Set(collections.map(\.id))
        let paletteIDs = Set(palettes.map(\.id))
        guard projectIDs.count == projects.count,
              collectionIDs.count == collections.count,
              paletteIDs.count == palettes.count,
              projects.allSatisfy({ !Self.isBlank($0.name) }),
              collections.allSatisfy({
                  !Self.isBlank($0.name) && ($0.projectID.map(projectIDs.contains) ?? true)
              }),
              palettes.allSatisfy({
                  !Self.isBlank($0.name) && ($0.collectionID.map(collectionIDs.contains) ?? true)
                      && !$0.hexColors.isEmpty && $0.hexColors.allSatisfy { StudioColor(hex: $0) != nil }
              }) else { throw LibraryBackupError.invalidContents }
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Merge by persistent ID so restoring a backup twice is safe.
    @MainActor
    func merge(into context: ModelContext) throws {
        try validate()
        let existingProjects = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StudioProject>()).map { ($0.id, $0) })
        let existingCollections = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StudioCollection>()).map { ($0.id, $0) })
        let existingPalettes = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StudioPalette>()).map { ($0.id, $0) })

        for item in projects {
            if let model = existingProjects[item.id] {
                model.name = item.name
                model.favorite = item.favorite
                model.order = item.order
            } else {
                context.insert(StudioProject(name: item.name, id: item.id, favorite: item.favorite, order: item.order))
            }
        }
        for item in collections {
            if let model = existingCollections[item.id] {
                model.name = item.name
                model.projectID = item.projectID
                model.favorite = item.favorite
                model.order = item.order
            } else {
                context.insert(StudioCollection(
                    name: item.name, projectID: item.projectID, id: item.id,
                    favorite: item.favorite, order: item.order
                ))
            }
        }
        for item in palettes {
            if let model = existingPalettes[item.id] {
                model.name = item.name
                model.hexColors = item.hexColors
                model.collectionID = item.collectionID
                model.favorite = item.favorite
                model.order = item.order
                model.updatedAt = item.updatedAt
            } else {
                context.insert(StudioPalette(
                    name: item.name, hexColors: item.hexColors, collectionID: item.collectionID,
                    id: item.id, favorite: item.favorite, order: item.order, updatedAt: item.updatedAt
                ))
            }
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

enum LibraryBackupError: LocalizedError {
    case unsupportedVersion
    case invalidContents

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This backup was created using an unsupported library version."
        case .invalidContents: "The backup contains invalid library records."
        }
    }
}
