import Foundation
import SwiftData

extension StudioLibraryView {
    func apply(_ action: LibraryNamePrompt.Action, name: String) {
        switch action {
        case .project:
            context.insert(StudioProject(name: name, order: nextLibraryOrder(projects.map(\.order))))
        case .collection:
            let projectID: UUID?
            switch scope {
            case .root: projectID = nil
            case .project(let id): projectID = id
            case .collection(let id): projectID = collections.first { $0.id == id }?.projectID
            }
            context.insert(StudioCollection(
                name: name, projectID: projectID,
                order: nextLibraryOrder(collections.map(\.order))
            ))
        case .rename(let item):
            item.name = name
        }
        saveChanges()
    }

    func saveChanges() {
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    func assign(_ collection: StudioCollection, to id: UUID?) {
        collection.projectID = id
        collection.order = nextLibraryOrder(collections.map(\.order))
        saveChanges()
    }

    func assign(_ palette: StudioPalette, to id: UUID?) {
        palette.collectionID = id
        palette.order = nextLibraryOrder(palettes.map(\.order))
        palette.updatedAt = .now
        saveChanges()
    }

    func delete(_ item: LibraryItem) {
        switch item {
        case .project(let model):
            for collection in collections where collection.projectID == model.id {
                collection.projectID = nil
            }
            if scope == .project(model.id) { scope = .root }
            context.delete(model)
        case .collection(let model):
            for palette in palettes where palette.collectionID == model.id {
                palette.collectionID = nil
                palette.updatedAt = .now
            }
            if scope == .collection(model.id) { scope = model.projectID.map(LibraryScope.project) ?? .root }
            context.delete(model)
        case .palette(let model):
            context.delete(model)
        }
        pendingDelete = nil
        saveChanges()
    }

    func movement(for item: LibraryItem) -> (siblings: [LibraryItem], index: Int) {
        let siblings: [LibraryItem]
        switch item {
        case .project:
            siblings = projects.map(LibraryItem.project)
        case .collection(let model):
            siblings = collections.filter { $0.projectID == model.projectID }.map(LibraryItem.collection)
        case .palette(let model):
            siblings = palettes.filter { $0.collectionID == model.collectionID }.map(LibraryItem.palette)
        }
        return (siblings, siblings.firstIndex { $0.id == item.id } ?? 0)
    }

    func move(_ item: LibraryItem, step: Int) {
        var (siblings, index) = movement(for: item)
        let target = index + step
        guard siblings.indices.contains(target), siblings.indices.contains(index) else { return }
        // Keep each sibling in its existing global sort slot while changing the sibling order.
        let occupiedSlots = siblings.map(\.order)
        siblings.swapAt(index, target)
        for (index, sibling) in siblings.enumerated() {
            sibling.order = occupiedSlots[index]
        }
        if Set(occupiedSlots).count != occupiedSlots.count {
            for (index, sibling) in siblings.enumerated() { sibling.order = index }
        }
        saveChanges()
    }

    func duplicate(_ item: LibraryItem) {
        let name = item.name + " Copy"
        var collectionOrder = nextLibraryOrder(collections.map(\.order))
        var paletteOrder = nextLibraryOrder(palettes.map(\.order))

        func copyPalette(_ original: StudioPalette, name: String, collectionID: UUID?) {
            context.insert(StudioPalette(
                name: name, hexColors: original.hexColors,
                collectionID: collectionID, favorite: original.favorite, order: paletteOrder
            ))
            paletteOrder = nextLibraryOrder([paletteOrder])
        }

        func copyCollection(_ original: StudioCollection, name: String, projectID: UUID?) {
            let model = StudioCollection(
                name: name, projectID: projectID, favorite: original.favorite, order: collectionOrder
            )
            collectionOrder = nextLibraryOrder([collectionOrder])
            context.insert(model)
            for palette in palettes where palette.collectionID == original.id {
                copyPalette(palette, name: palette.name, collectionID: model.id)
            }
        }

        switch item {
        case .project(let original):
            let model = StudioProject(
                name: name, favorite: original.favorite,
                order: nextLibraryOrder(projects.map(\.order))
            )
            context.insert(model)
            for collection in collections where collection.projectID == original.id {
                copyCollection(collection, name: collection.name, projectID: model.id)
            }
        case .collection(let original):
            copyCollection(original, name: name, projectID: original.projectID)
        case .palette(let original):
            copyPalette(original, name: name, collectionID: original.collectionID)
        }
        saveChanges()
    }
}
