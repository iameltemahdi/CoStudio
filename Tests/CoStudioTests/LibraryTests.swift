import Foundation
import SwiftData
import XCTest
@testable import CoStudio

final class LibraryTests: XCTestCase {
    private struct PredictableRandom: RandomNumberGenerator {
        private var current: UInt64 = 12345

        mutating func next() -> UInt64 {
            current = 2_862_933_555_777_941_757 &* current &+ 3_037_000_493
            return current
        }
    }

    func testComplementaryRecipeKeepsLockedColorAndUsesItsHue() throws {
        let locked = try XCTUnwrap(StudioColor(hex: "#FF000080"))
        let original = Array(repeating: StudioColor(red: 0.3, green: 0.3, blue: 0.3), count: 5)
        var swatches = original
        swatches[3] = locked
        var generator = PredictableRandom()
        let generated = PaletteHarmony.complementary.generate(colors: swatches, locked: [3], using: &generator)

        XCTAssertEqual(generated[3], locked)
        XCTAssertEqual(generated[0].hsl.hue, 180, accuracy: 0.001)
        XCTAssertEqual(generated[1].hsl.hue, 0, accuracy: 0.001)
        XCTAssertNotEqual(generated[2], original[2])
    }

    func testGradientCoordinatesAndExportUseSortedStops() throws {
        let first = try XCTUnwrap(StudioColor(hex: "#11223380"))
        let second = try XCTUnwrap(StudioColor(hex: "#FFFFFF"))
        var recipe = GradientRecipe(angle: 90, stops: [
            StudioGradientStop(color: second, position: 1),
            StudioGradientStop(color: first, position: 0)
        ])
        let axis = recipe.axis(width: 400, height: 200)
        XCTAssertEqual(axis.start.x, 0, accuracy: 0.0001)
        XCTAssertEqual(axis.start.y, 100, accuracy: 0.0001)
        XCTAssertEqual(axis.end.x, 400, accuracy: 0.0001)
        XCTAssertEqual(axis.end.y, 100, accuracy: 0.0001)
        XCTAssertEqual(recipe.css, "linear-gradient(90.0deg, #11223380 0.0%, #FFFFFF 100.0%)")
        XCTAssertTrue(recipe.svg().contains(##"stop-color="#112233" stop-opacity="0.5020""##))
        recipe.kind = .radial
        XCTAssertTrue(recipe.css.hasPrefix("radial-gradient(circle closest-side at center,"))
        XCTAssertTrue(recipe.svg(width: 400, height: 200).contains(#"r="100.0000""#))
    }

    func testPaletteExportsPreserveAlphaAndUseKnownAdobeHeaders() throws {
        let color = try XCTUnwrap(StudioColor(hex: "#FF000080"))
        let json = try PaletteExport.json.data(name: "Red & Rust", colors: [color])
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertEqual(parsed["name"] as? String, "Red & Rust")
        XCTAssertEqual(parsed["colors"] as? [String], ["#FF000080"])
        let tokenJSON = try PaletteExport.tokens.data(name: "Red & Rust", colors: [color])
        let tokenRoot = try XCTUnwrap(JSONSerialization.jsonObject(with: tokenJSON) as? [String: [String: [String: Any]]])
        XCTAssertEqual(tokenRoot["palette"]?["swatch-1"]?["$type"] as? String, "color")
        let svg = try PaletteExport.svg.data(name: "Red & Rust", colors: [color])
        XCTAssertTrue(String(decoding: svg, as: UTF8.self).contains("Red &amp; Rust"))
        let ase = try PaletteExport.ase.data(name: "Red", colors: [color])
        XCTAssertEqual(Array(ase.prefix(12)), [65, 83, 69, 70, 0, 1, 0, 0, 0, 0, 0, 1])
        XCTAssertEqual(ase.count, 54)
        let aco = try PaletteExport.aco.data(name: "Red", colors: [color])
        XCTAssertEqual(Array(aco), [0, 1, 0, 1, 0, 0, 255, 255, 0, 0, 0, 0, 0, 0])
    }

    @MainActor
    func testSnapshotRestoresHierarchyAndPersistsAcrossContainers() throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let schema = Schema([StudioPalette.self, StudioProject.self, StudioCollection.self])
        let configuration = ModelConfiguration(
            schema: schema, url: temporary.appending(path: "Library.store"), cloudKitDatabase: .none
        )
        let project = StudioProject(name: "Brand")
        let collection = StudioCollection(name: "Spring", projectID: project.id)
        let palette = StudioPalette(
            name: "Moss", hexColors: ["#00FF00", "#11223380"],
            collectionID: collection.id, favorite: true
        )
        let backup = LibrarySnapshot(projects: [project], collections: [collection], palettes: [palette])
        let package = temporary.appending(path: "Color Studio.costudiobackup", directoryHint: .isDirectory)
        let document = LibraryBackupDocument(libraryData: try backup.encoded())
        let wrapper = try document.packageWrapper()
        try wrapper.write(to: package, options: .atomic, originalContentsURL: nil)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let snapshot = try LibraryBackupDocument.readPackage(at: package)
            try LibraryBackupDocument.restore(snapshot, into: container.mainContext)
            try LibraryBackupDocument.restore(snapshot, into: container.mainContext)
        }

        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let projects = try reopened.mainContext.fetch(FetchDescriptor<StudioProject>())
        let collections = try reopened.mainContext.fetch(FetchDescriptor<StudioCollection>())
        let palettes = try reopened.mainContext.fetch(FetchDescriptor<StudioPalette>())
        XCTAssertEqual(projects.map(\.id), [project.id])
        XCTAssertEqual(collections.map(\.projectID), [project.id])
        XCTAssertEqual(palettes.map(\.collectionID), [collection.id])
        XCTAssertEqual(palettes.first?.hexColors, ["#00FF00", "#11223380"])
        XCTAssertEqual(palettes.first?.favorite, true)
    }

    func testBackupRejectsDanglingCollectionReference() throws {
        let palette = StudioPalette(name: "Moss", hexColors: ["#112233"], collectionID: UUID())
        let backup = LibrarySnapshot(projects: [], collections: [], palettes: [palette])
        XCTAssertThrowsError(try LibrarySnapshot.decode(backup.encoded())) { error in
            XCTAssertEqual(error as? LibraryBackupError, .invalidContents)
        }
    }
}
