import XCTest
@testable import CoStudio

final class ColorTests: XCTestCase {
    func testHexSyntaxAlphaAndCodingValidation() throws {
        let color = try XCTUnwrap(StudioColor(hex: "  #07c8 "))
        XCTAssertEqual(color.hex, "#0077CC")
        XCTAssertEqual(color.hexWithAlpha, "#0077CC88")
        XCTAssertEqual(color.alpha, 136.0 / 255, accuracy: 0.0000001)
        XCTAssertEqual(try JSONDecoder().decode(StudioColor.self, from: JSONEncoder().encode(color)), color)

        for invalid in ["+#123", "#-123", "##fff", "#１２１２１２", "1234567", "abcdefg", "#"] {
            XCTAssertNil(StudioColor(hex: invalid), invalid)
        }
        let bad = Data(#"{"red":1.1,"green":0,"blue":0,"alpha":1}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(StudioColor.self, from: bad))
    }

    func testHSLHSVAndCMYKFromKnownColors() throws {
        let red = try XCTUnwrap(StudioColor(hex: "#FF0000"))
        XCTAssertEqual(red.hsl.hue, 0)
        XCTAssertEqual(red.hsl.saturation, 1)
        XCTAssertEqual(red.hsl.lightness, 0.5)
        XCTAssertEqual(red.hsv.value, 1)
        XCTAssertEqual(red.cmyk.cyan, 0)
        XCTAssertEqual(red.cmyk.magenta, 1)
        XCTAssertEqual(StudioColor.black.cmyk.key, 1)
        XCTAssertEqual(StudioColor(hue: -120, saturation: 1, lightness: 0.5).hex, "#0000FF")
        XCTAssertEqual(StudioColor(hue: 480, saturation: 1, value: 0.5).hex, "#008000")
    }

    func testPerceptualColorSpacesMatchReferences() throws {
        let red = try XCTUnwrap(StudioColor(hex: "#FF0000"))
        // Red in CIE Lab, using CSS Color 4's D50 white point.
        XCTAssertEqual(red.lab.lightness, 54.29, accuracy: 0.01)
        XCTAssertEqual(red.lab.a, 80.81, accuracy: 0.01)
        XCTAssertEqual(red.lab.b, 69.89, accuracy: 0.01)
        // Björn Ottosson's original Oklab transform for linear sRGB red.
        XCTAssertEqual(red.oklab.lightness, 0.627955, accuracy: 0.000003)
        XCTAssertEqual(red.oklab.a, 0.224863, accuracy: 0.000003)
        XCTAssertEqual(red.oklab.b, 0.125846, accuracy: 0.000003)
        XCTAssertEqual(try XCTUnwrap(red.oklch.hue), 29.2339, accuracy: 0.001)
        XCTAssertNil(StudioColor.white.lch.hue)
        XCTAssertNil(StudioColor.middleGray.oklch.hue)
        XCTAssertEqual(StudioColor.white.lab.lightness, 100, accuracy: 0.000001)
    }

    func testColorFormatRoundTripPreservesChannelPrecision() throws {
        let inputs = ["#000000", "#FFFFFF", "#639179BF", "#FF0000", "#0022FF", "#232323"]
        for input in inputs {
            let original = try XCTUnwrap(StudioColor(hex: input))
            for format in StudioColorFormat.allCases {
                let output = format.string(for: original)
                let parsed = try XCTUnwrap(format.parse(output), "\(input) \(output)")
                XCTAssertEqual(parsed.red, original.red, accuracy: 0.0015, output)
                XCTAssertEqual(parsed.green, original.green, accuracy: 0.0015, output)
                XCTAssertEqual(parsed.blue, original.blue, accuracy: 0.0015, output)
                XCTAssertEqual(parsed.alpha, original.alpha, accuracy: 0.0005, output)
            }
        }
        XCTAssertEqual(StudioColorFormat.rgb.parse("rgb(100% 0% 0% / 50%)")?.alpha, 0.5)
        XCTAssertNil(StudioColorFormat.hsl.parse("180 150% 25%"))
        XCTAssertNil(StudioColorFormat.lab.parse("50% nan 5"))
    }

    func testWCAGContrastThresholdsAndAlpha() throws {
        XCTAssertEqual(ContrastReport(foreground: .black, background: .white).ratio, 21, accuracy: 0.0000001)
        XCTAssertEqual(ContrastReport(foreground: .white, background: .white).ratio, 1)
        let gray = try XCTUnwrap(StudioColor(hex: "#777"))
        let report = ContrastReport(foreground: gray, background: .white)
        XCTAssertEqual(report.ratio, 4.47809, accuracy: 0.00001)
        XCTAssertFalse(report.passes(.normalAA))
        XCTAssertTrue(report.passes(.largeAA))
        XCTAssertFalse(report.passes(.normalAAA))
        XCTAssertFalse(report.passes(.largeAAA))
        let translucent = ContrastReport(foreground: .black.withAlpha(0.5), background: .white)
        XCTAssertEqual(translucent.renderedForeground, .middleGray)
        XCTAssertEqual(translucent.ratio, 3.97665, accuracy: 0.00001)
    }

    func testSuggestionsMeetTargetAndRespectOpacity() throws {
        let gray = try XCTUnwrap(StudioColor(hex: "#bbbbbb"))
        let suggestions = ContrastReport.suggestions(foreground: gray, background: .white, threshold: 4.5)
        XCTAssertEqual(suggestions.count, 1)
        for suggestion in suggestions {
            XCTAssertTrue(ContrastReport(foreground: suggestion, background: .white).passes(.normalAA))
            let exported = try XCTUnwrap(StudioColor(hex: suggestion.displayHex))
            XCTAssertTrue(ContrastReport(foreground: exported, background: .white).passes(.normalAA))
        }
        XCTAssertTrue(ContrastReport.suggestions(foreground: gray.withAlpha(0.1), background: .white, threshold: 4.5).isEmpty)
    }

    func testColorVisionUsesLinearSimulationAndPreservesAlpha() {
        let red = StudioColor(red: 1, green: 0, blue: 0, alpha: 0.4)
        XCTAssertEqual(ColorVisionMode.protanopia.simulate(red).hex, "#6D5F00")
        XCTAssertEqual(ColorVisionMode.deuteranopia.simulate(red).hex, "#A39000")
        XCTAssertEqual(ColorVisionMode.tritanopia.simulate(red).hex, "#FF000F")
        let grayscale = ColorVisionMode.achromatopsia.simulate(red)
        XCTAssertEqual(grayscale.hex, "#7F7F7F")
        XCTAssertEqual(grayscale.alpha, 0.4)
        XCTAssertEqual(grayscale.relativeLuminance, red.relativeLuminance, accuracy: 0.000001)
    }

    func testNamedColorsAndCombinations() throws {
        XCTAssertEqual(NamedColor.library.count, 148)
        let purple = try XCTUnwrap(NamedColor.library.first { $0.name == "rebeccapurple" })
        XCTAssertEqual(purple.color.hex, "#663399")
        XCTAssertEqual(purple.family, .violet)
        XCTAssertEqual(NamedColor.nearest(to: purple.color, count: 1).first?.id, purple.id)
        let red = try XCTUnwrap(StudioColor(hex: "#FF0000"))
        XCTAssertEqual(ColorHarmony.complementary.colors(from: red).map(\.hex), ["#FF0000", "#00FFFF"])
        XCTAssertEqual(ColorHarmony.triadic.colors(from: red).map(\.hex), ["#FF0000", "#00FF00", "#0000FF"])
    }
}
