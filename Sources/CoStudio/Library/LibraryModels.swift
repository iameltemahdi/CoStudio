import Foundation
import SwiftData

@Model
final class StudioPalette {
    @Attribute(.unique) var id: UUID
    var name: String
    var hexColors: [String]
    var collectionID: UUID?
    var favorite: Bool
    var order: Int
    var updatedAt: Date

    init(
        name: String, hexColors: [String], collectionID: UUID? = nil,
        id: UUID = UUID(), favorite: Bool = false, order: Int = 0, updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.hexColors = hexColors
        self.collectionID = collectionID
        self.favorite = favorite
        self.order = order
        self.updatedAt = updatedAt
    }
}

@Model
final class StudioProject {
    @Attribute(.unique) var id: UUID
    var name: String
    var favorite: Bool
    var order: Int

    init(name: String, id: UUID = UUID(), favorite: Bool = false, order: Int = 0) {
        self.id = id
        self.name = name
        self.favorite = favorite
        self.order = order
    }
}

@Model
final class StudioCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var projectID: UUID?
    var favorite: Bool
    var order: Int

    init(
        name: String, projectID: UUID? = nil, id: UUID = UUID(),
        favorite: Bool = false, order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.projectID = projectID
        self.favorite = favorite
        self.order = order
    }
}
