import Foundation

enum LibraryScope: Equatable {
    case root
    case project(UUID)
    case collection(UUID)
}

enum LibraryItem: Identifiable {
    case project(StudioProject)
    case collection(StudioCollection)
    case palette(StudioPalette)

    var id: UUID {
        switch self {
        case .project(let model): model.id
        case .collection(let model): model.id
        case .palette(let model): model.id
        }
    }

    var name: String {
        get {
            switch self {
            case .project(let model): model.name
            case .collection(let model): model.name
            case .palette(let model): model.name
            }
        }
        nonmutating set {
            switch self {
            case .project(let model): model.name = newValue
            case .collection(let model): model.name = newValue
            case .palette(let model):
                model.name = newValue
                model.updatedAt = .now
            }
        }
    }

    var favorite: Bool {
        get {
            switch self {
            case .project(let model): model.favorite
            case .collection(let model): model.favorite
            case .palette(let model): model.favorite
            }
        }
        nonmutating set {
            switch self {
            case .project(let model): model.favorite = newValue
            case .collection(let model): model.favorite = newValue
            case .palette(let model): model.favorite = newValue
            }
        }
    }

    var order: Int {
        get {
            switch self {
            case .project(let model): model.order
            case .collection(let model): model.order
            case .palette(let model): model.order
            }
        }
        nonmutating set {
            switch self {
            case .project(let model): model.order = newValue
            case .collection(let model): model.order = newValue
            case .palette(let model): model.order = newValue
            }
        }
    }

    var symbol: String {
        switch self {
        case .project: "folder"
        case .collection: "square.stack"
        case .palette: "swatchpalette"
        }
    }

    var deletionNote: String {
        switch self {
        case .project: "Its collections and palettes will remain in your library."
        case .collection: "Its palettes will remain in your library."
        case .palette: "The saved palette will be removed from your library."
        }
    }
}

func nextLibraryOrder(_ values: [Int]) -> Int {
    let current = values.max() ?? -1
    return current < Int.max ? current + 1 : current
}

struct LibraryNamePrompt: Identifiable {
    enum Action {
        case project
        case collection
        case rename(LibraryItem)
    }

    let id = UUID()
    let action: Action
    var name: String

    var title: String {
        switch action {
        case .project: "New Project"
        case .collection: "New Collection"
        case .rename: "Rename"
        }
    }
}

struct LibraryPaletteEdit: Identifiable {
    let id = UUID()
    var palette: StudioPalette?
    var collectionID: UUID?
}
