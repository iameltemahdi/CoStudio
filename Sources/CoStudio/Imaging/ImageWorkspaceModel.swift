import CoreGraphics
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct ExportedArtwork: FileDocument {
    static var readableContentTypes: [UTType] { [.png, .jpeg, .tiff] }
    var data: Data

    init(_ data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw ImageStudioError.invalidImage }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
@Observable
final class ImageWorkspaceModel {
    private(set) var original: CGImage?
    private(set) var image: CGImage?
    private(set) var preview: CGImage?
    private(set) var previewEdit: ImageEdit?
    private(set) var current: ImportedArtwork?
    private(set) var artwork: [ImportedArtwork] = []
    private(set) var history = ImageEditHistory()
    private(set) var busy = false
    var errorMessage: String?
    var status: String?
    var pickedColor: StudioColor?
    var loupe: CGImage?
    var pickedPosition: CGPoint?
    var extractedColors: [StudioColor] = []

    func restoreCatalog() {
        handle {
            artwork = try ImageLibrary.load().images
        }
    }

    func open(_ artwork: ImportedArtwork) async {
        await run {
            let loaded = try await Task.detached(priority: .userInitiated) {
                guard let latest = try ImageLibrary.load().images.first(where: { $0.id == artwork.id }) else {
                    throw ImageStudioError.missingOriginal
                }
                let original = try ImagePipeline.load(ImageLibrary.original(latest))
                let displayed = try ImagePipeline.render(original, edits: latest.edits)
                return (latest, original, displayed)
            }.value
            restoreCatalog()
            setArtwork(loaded.0, images: (loaded.1, loaded.2))
        }
    }

    func importImage(_ file: URL) async {
        await run {
            let imported = try await Task.detached(priority: .userInitiated) {
                let artwork = try ImageLibrary.importImage(file)
                let original = try ImagePipeline.load(ImageLibrary.original(artwork))
                let displayed = try ImagePipeline.render(original, edits: artwork.edits)
                return (artwork, original, displayed)
            }.value
            restoreCatalog()
            setArtwork(imported.0, images: (imported.1, imported.2))
            status = "Original saved to the local library."
        }
    }

    func remove(_ item: ImportedArtwork) {
        handle {
            try ImageLibrary.remove(item)
            restoreCatalog()
            if current?.id == item.id {
                current = nil
                original = nil
                image = nil
                history = ImageEditHistory()
                clearSelection()
            }
        }
    }

    func select(at position: CGPoint, from displayed: CGImage) {
        let x = max(0, min(displayed.width - 1, Int(position.x * Double(displayed.width))))
        let y = max(0, min(displayed.height - 1, Int(position.y * Double(displayed.height))))
        if pickedPosition == CGPoint(x: x, y: y) { return }
        handle {
            pickedColor = try ImagePipeline.sample(displayed, x: x, y: y)
            pickedPosition = CGPoint(x: x, y: y)
            loupe = ImagePipeline.loupe(displayed, x: x, y: y)
        }
    }

    func extract(_ count: Int) async {
        guard let image else { return }
        await run {
            extractedColors = try await Task.detached(priority: .userInitiated) {
                try ImagePipeline.dominantColors(in: image, count: count)
            }.value
            if extractedColors.isEmpty { status = "There are no visible colors to extract." }
        }
    }

    func showPreview(_ edit: ImageEdit) async {
        guard let image else { return }
        await run {
            preview = try await Task.detached(priority: .userInitiated) {
                try ImagePipeline.render(image, edit: edit)
            }.value
            previewEdit = edit
            pickedPosition = nil
        }
    }

    func discardPreview() {
        preview = nil
        previewEdit = nil
        clearSelection()
    }

    func commitPreview() {
        guard let preview, let previewEdit else { return }
        handle {
            var next = history
            next.append(previewEdit)
            try persist(next)
            self.image = preview
            discardPreview()
        }
    }

    func apply(_ edit: ImageEdit) async {
        guard let image else { return }
        await run {
            let output = try await Task.detached(priority: .userInitiated) {
                try ImagePipeline.render(image, edit: edit)
            }.value
            var next = history
            next.append(edit)
            try persist(next)
            self.image = output
            discardPreview()
        }
    }

    func undo() async {
        var next = history
        next.undo()
        await move(to: next)
    }

    func redo() async {
        var next = history
        next.redo()
        await move(to: next)
    }

    func reset() async { await move(to: ImageEditHistory()) }

    func export(_ format: StudioImageFormat) async -> ExportedArtwork? {
        guard let image else { return nil }
        var result: ExportedArtwork?
        await run {
            let data = try await Task.detached(priority: .userInitiated) {
                try ImagePipeline.encode(image, format: format)
            }.value
            result = ExportedArtwork(data)
        }
        return result
    }

    func clearSelection() {
        pickedColor = nil
        pickedPosition = nil
        loupe = nil
        extractedColors = []
    }

    private func setArtwork(_ artwork: ImportedArtwork, images: (CGImage, CGImage)) {
        current = artwork
        original = images.0
        image = images.1
        history = ImageEditHistory(applied: artwork.edits)
        status = nil
        discardPreview()
    }

    private func move(to next: ImageEditHistory) async {
        guard let original, next != history else { return }
        let edits = next.applied
        await run {
            let output = try await Task.detached(priority: .userInitiated) {
                try ImagePipeline.render(original, edits: edits)
            }.value
            try persist(next)
            image = output
            discardPreview()
        }
    }

    private func persist(_ next: ImageEditHistory) throws {
        guard var current else { return }
        current.edits = next.applied
        try ImageLibrary.update(current, replacing: history.applied)
        self.current = current
        history = next
        restoreCatalog()
    }

    private func handle(_ operation: () throws -> Void) {
        do { try operation() } catch { errorMessage = error.localizedDescription }
    }

    private func run(_ operation: () async throws -> Void) async {
        guard !busy else { return }
        busy = true
        status = nil
        defer { busy = false }
        do { try await operation() } catch { errorMessage = error.localizedDescription }
    }
}
