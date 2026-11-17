import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import CoStudio

final class ImageTests: XCTestCase {
    func testSamplingAndCropUseTopLeftCoordinates() throws {
        let image = try fixture()
        XCTAssertEqual(try ImagePipeline.sample(image, x: 0, y: 0).hex, "#FF0000")
        XCTAssertEqual(try ImagePipeline.sample(image, x: 1, y: 1).hex, "#FFFFFF")

        let crop = ImageCrop(left: 0.5, top: 0, right: 1, bottom: 0.5)
        let region = try ImagePipeline.render(image, edit: .crop(crop))
        XCTAssertEqual(region.width, 1)
        XCTAssertEqual(region.height, 1)
        XCTAssertEqual(try ImagePipeline.sample(region, x: 0, y: 0).hex, "#00FF00")
    }

    func testClockwiseRotationMovesTopLeftToTopRight() throws {
        let original = try fixture()
        let rotated = try ImagePipeline.render(original, edit: .rotateClockwise)
        XCTAssertEqual(try ImagePipeline.sample(rotated, x: 1, y: 0).hex, "#FF0000")
        XCTAssertEqual(try ImagePipeline.sample(rotated, x: 0, y: 1).hex, "#FFFFFF")
    }

    func testReplacementPreservesOtherColorsAndAlpha() throws {
        let image = try makeImage(width: 2, height: 1, pixels: [128, 0, 0, 128, 0, 0, 255, 255])
        let edited = try ImagePipeline.replace(
            StudioColor(red: 1, green: 0, blue: 0),
            with: StudioColor(red: 0, green: 1, blue: 0),
            tolerance: 0.05,
            in: image
        )
        XCTAssertEqual(try ImagePipeline.sample(edited, x: 0, y: 0).hexWithAlpha, "#00FF0080")
        XCTAssertEqual(try ImagePipeline.sample(edited, x: 1, y: 0).hexWithAlpha, "#0000FFFF")
    }

    func testDominantPaletteIsDeterministicAndIgnoresTransparency() throws {
        let pixels: [UInt8] = [
            255, 0, 0, 255, 255, 0, 0, 255,
            0, 0, 255, 255, 0, 0, 0, 0
        ]
        let image = try makeImage(width: 4, height: 1, pixels: pixels)
        let colors = try ImagePipeline.dominantColors(in: image, count: 6)
        XCTAssertEqual(colors.map(\.hex), ["#FF0000", "#0000FF"])
        XCTAssertEqual(colors, try ImagePipeline.dominantColors(in: image, count: 6))
    }

    func testPaletteMapsBlackAndWhiteToEndpoints() throws {
        let image = try makeImage(width: 2, height: 1, pixels: [0, 0, 0, 255, 255, 255, 255, 255])
        let low = StudioColor(red: 0, green: 0, blue: 1)
        let high = StudioColor(red: 1, green: 0, blue: 0)
        let edited = try ImagePipeline.mapPalette([low, high], intensity: 1, in: image)
        XCTAssertEqual(try ImagePipeline.sample(edited, x: 0, y: 0).hex, low.hex)
        XCTAssertEqual(try ImagePipeline.sample(edited, x: 1, y: 0).hex, high.hex)
    }

    func testUndoRedoRendersFromOriginalAndNewActionClearsRedo() throws {
        let image = try fixture()
        var history = ImageEditHistory()
        history.append(.rotateClockwise)
        history.append(.crop(ImageCrop(left: 0.5)))
        XCTAssertEqual(try ImagePipeline.render(image, edits: history.applied).width, 1)
        history.undo()
        XCTAssertEqual(try ImagePipeline.render(image, edits: history.applied).width, 2)
        history.redo()
        XCTAssertEqual(try ImagePipeline.render(image, edits: history.applied).width, 1)
        history.undo()
        history.append(.rotateClockwise)
        XCTAssertTrue(history.undone.isEmpty)
        XCTAssertEqual(try ImagePipeline.sample(ImagePipeline.render(image, edits: history.applied), x: 0, y: 0).hex, "#FFFFFF")
    }

    func testPNGAndTIFFKeepAlphaAndJPEGFlattensIt() throws {
        let image = try makeImage(width: 1, height: 1, pixels: [128, 0, 0, 128])
        for format in StudioImageFormat.allCases {
            let encoded = try ImagePipeline.encode(image, format: format)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(encoded as CFData, nil))
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(CGImageSourceGetType(source) as String?, format.contentType.identifier)
            let color = try ImagePipeline.sample(decoded, x: 0, y: 0)
            XCTAssertEqual(color.alpha, format == .jpeg ? 1 : 128.0 / 255, accuracy: 0.001)
        }
    }

    func testLocalLibraryDeduplicatesImportsAndRestoresRecipes() throws {
        let temp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        let original = temp.appending(path: "Original.png")
        let firstLibrary = temp.appending(path: "First")
        let secondLibrary = temp.appending(path: "Second")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let data = try ImagePipeline.encode(fixture(), format: .png)
        try data.write(to: original)
        var stored = try ImageLibrary.importImage(original, in: firstLibrary)
        XCTAssertEqual(try ImageLibrary.importImage(original, in: firstLibrary).id, stored.id)
        XCTAssertEqual(try ImageLibrary.load(in: firstLibrary).images.count, 1)

        stored.edits = [.rotateClockwise]
        try ImageLibrary.update(stored, in: firstLibrary)
        XCTAssertThrowsError(try ImageLibrary.update(stored, replacing: [], in: firstLibrary))
        try ImageLibrary.merge(from: firstLibrary, into: secondLibrary)
        XCTAssertEqual(try ImageLibrary.load(in: secondLibrary).images, [stored])
        let restored = try ImageLibrary.original(stored, in: secondLibrary)
        XCTAssertEqual(try Data(contentsOf: restored), data)
        XCTAssertEqual(try ImagePipeline.load(restored).width, 2)
    }

    func testBackupRejectsPathTraversalBeforeCopyingOriginals() throws {
        let temp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        let firstLibrary = temp.appending(path: "Backup")
        let secondLibrary = temp.appending(path: "Local")
        try FileManager.default.createDirectory(at: firstLibrary, withIntermediateDirectories: true)
        let entry = ImportedArtwork(id: "../unexpected", name: "Invalid", importedAt: .now)
        let data = try JSONEncoder().encode(ImageLibrary.Catalog(images: [entry]))
        try data.write(to: firstLibrary.appending(path: "catalog.json"))
        XCTAssertThrowsError(try ImageLibrary.merge(from: firstLibrary, into: secondLibrary))
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondLibrary.path))
    }

    private func fixture() throws -> CGImage {
        try makeImage(
            width: 2, height: 2,
            pixels: [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]
        )
    }

    private func makeImage(width: Int, height: Int, pixels: [UInt8]) throws -> CGImage {
        let storage = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        let bitmap = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        return try XCTUnwrap(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: ImagePipeline.colorSpace,
            bitmapInfo: bitmap, provider: storage, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent
        ))
    }
}
