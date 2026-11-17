import Foundation
import UniformTypeIdentifiers

enum PaletteExport: String, CaseIterable, Identifiable {
    case hex = "HEX list"
    case json = "JSON"
    case css = "CSS variables"
    case scss = "SCSS variables"
    case tokens = "Design tokens"
    case svg = "SVG swatches"
    case ase = "Adobe ASE"
    case aco = "Adobe ACO"

    var id: Self { self }

    var fileExtension: String {
        switch self {
        case .hex: "txt"
        case .json, .tokens: "json"
        case .css: "css"
        case .scss: "scss"
        case .svg: "svg"
        case .ase: "ase"
        case .aco: "aco"
        }
    }

    var contentType: UTType {
        switch self {
        case .hex: .plainText
        case .json, .tokens: .json
        case .svg: .svg
        case .ase, .aco: .data
        case .css, .scss: UTType(filenameExtension: fileExtension) ?? .plainText
        }
    }

    func data(name: String, colors: [StudioColor]) throws -> Data {
        let values = colors.map(\.exportHex)
        let json = JSONEncoder()
        json.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        switch self {
        case .hex:
            return Data((values.joined(separator: "\n") + "\n").utf8)
        case .json:
            return try json.encode(PaletteJSON(name: name, colors: values))
        case .css:
            let lines = values.enumerated().map { "  --color-\($0.offset + 1): \($0.element);" }
            return Data((":root {\n" + lines.joined(separator: "\n") + "\n}\n").utf8)
        case .scss:
            let lines = values.enumerated().map { "$color-\($0.offset + 1): \($0.element);" }
            return Data((lines.joined(separator: "\n") + "\n").utf8)
        case .tokens:
            let entries = colors.enumerated().map { index, color in
                (
                    "swatch-\(index + 1)",
                    ColorToken(
                        type: "color",
                        value: ColorToken.Value(
                            colorSpace: "srgb",
                            components: [color.red, color.green, color.blue],
                            alpha: color.alpha,
                            hex: color.hex
                        )
                    )
                )
            }
            return try json.encode(["palette": Dictionary(uniqueKeysWithValues: entries)])
        case .svg:
            let width = max(colors.count, 1) * 120
            let rects = colors.enumerated().map { index, color in
                "  <rect x=\"\(index * 120)\" width=\"120\" height=\"160\" fill=\"\(color.hex)\" fill-opacity=\"\(creativeDecimal(color.alpha))\"/>"
            }
            return Data(
                ("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(width) 160\">\n"
                    + "  <title>\(xmlEscaped(name))</title>\n"
                    + rects.joined(separator: "\n") + "\n</svg>\n").utf8
            )
        case .ase:
            return adobeSwatchExchange(colors)
        case .aco:
            guard colors.count <= Int(UInt16.max) else { throw CreativeExportError.tooManySwatches }
            return adobeColorSwatches(colors)
        }
    }

    private func adobeSwatchExchange(_ colors: [StudioColor]) -> Data {
        var data = Data("ASEF".utf8)
        data.appendBigEndian(UInt16(1))
        data.appendBigEndian(UInt16(0))
        data.appendBigEndian(UInt32(colors.count))
        for color in colors {
            let name = Array(color.hex.utf16)
            let blockLength = 2 + (name.count + 1) * 2 + 4 + 3 * 4 + 2
            data.appendBigEndian(UInt16(1))
            data.appendBigEndian(UInt32(blockLength))
            data.appendBigEndian(UInt16(name.count + 1))
            for unit in name { data.appendBigEndian(unit) }
            data.appendBigEndian(UInt16(0))
            data.append(Data("RGB ".utf8))
            for channel in [color.red, color.green, color.blue] {
                data.appendBigEndian(Float(channel).bitPattern)
            }
            data.appendBigEndian(UInt16(2)) // Normal color.
        }
        return data
    }

    private func adobeColorSwatches(_ colors: [StudioColor]) -> Data {
        var data = Data()
        data.appendBigEndian(UInt16(1))
        data.appendBigEndian(UInt16(colors.count))
        for color in colors {
            data.appendBigEndian(UInt16(0)) // RGB color space.
            for channel in [color.red, color.green, color.blue] {
                data.appendBigEndian(UInt16((channel * Double(UInt16.max)).rounded()))
            }
            data.appendBigEndian(UInt16(0)) // Unused fourth RGB channel.
        }
        return data
    }
}

private struct PaletteJSON: Encodable {
    let name: String
    let colors: [String]
}

private struct ColorToken: Encodable {
    struct Value: Encodable {
        let colorSpace: String
        let components: [Double]
        let alpha: Double
        let hex: String
    }

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case value = "$value"
    }

    let type: String
    let value: Value
}

enum CreativeExportError: LocalizedError {
    case tooManySwatches

    var errorDescription: String? { "This file format supports up to 65,535 swatches." }
}

private extension Data {
    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        append(Swift.withUnsafeBytes(of: &bigEndian) { Data($0) })
    }
}

extension StudioColor {
    var exportHex: String { alpha < 1 ? hexWithAlpha : hex }
}

func xmlEscaped(_ string: String) -> String {
    string.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

func creativeDecimal(_ value: Double, precision: Int = 4) -> String {
    String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), precision, value)
}
