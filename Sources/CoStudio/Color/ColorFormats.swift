import Foundation

enum StudioColorFormat: String, CaseIterable, Identifiable {
    case hex = "HEX", rgb = "RGB", rgba = "RGBA", hsl = "HSL", hsv = "HSV", cmyk = "CMYK"
    case lab = "Lab", lch = "LCH", oklab = "OKLab", oklch = "OKLCH"
    var id: Self { self }

    var inputHint: String {
        switch self {
        case .hex: return "#RRGGBB or #RRGGBBAA"
        case .rgb: return "R G B · channels 0–255"
        case .rgba: return "R G B A · alpha 0–1"
        case .hsl: return "Hue° saturation% lightness%"
        case .hsv: return "Hue° saturation% value%"
        case .cmyk: return "C% M% Y% K% · generic approximation"
        case .lab: return "L% a b · D50 white"
        case .lch: return "L% chroma hue° · D50 white"
        case .oklab: return "L a b · lightness 0–1 or %"
        case .oklch: return "L chroma hue° · lightness 0–1 or %"
        }
    }

    func string(for color: StudioColor) -> String {
        let rgb = color.rgb8
        let alpha = color.alpha < 1 ? " / " + Self.decimal(color.alpha, precision: 3) : ""
        switch self {
        case .hex: return color.displayHex
        case .rgb: return "rgb(\(rgb.red) \(rgb.green) \(rgb.blue)\(alpha))"
        case .rgba: return "rgba(\(rgb.red), \(rgb.green), \(rgb.blue), \(Self.decimal(color.alpha, precision: 3)))"
        case .hsl:
            let c = color.hsl
            return "hsl(\(Self.decimal(c.hue)) \(Self.percent(c.saturation)) \(Self.percent(c.lightness))\(alpha))"
        case .hsv:
            let c = color.hsv
            return "hsv(\(Self.decimal(c.hue)) \(Self.percent(c.saturation)) \(Self.percent(c.value))\(alpha))"
        case .cmyk:
            let c = color.cmyk
            let channels = [c.cyan, c.magenta, c.yellow, c.key].map { Self.percent($0) }
            return "cmyk(\(channels.joined(separator: " "))\(alpha))"
        case .lab:
            let c = color.lab
            return "lab(\(Self.decimal(c.lightness))% \(Self.decimal(c.a)) \(Self.decimal(c.b))\(alpha))"
        case .lch:
            let c = color.lch
            let hue = c.hue.map { Self.decimal($0) } ?? "none"
            return "lch(\(Self.decimal(c.lightness))% \(Self.decimal(c.chroma)) \(hue)\(alpha))"
        case .oklab:
            let c = color.oklab
            return "oklab(\(Self.decimal(c.lightness, precision: 5)) \(Self.decimal(c.a, precision: 5)) \(Self.decimal(c.b, precision: 5))\(alpha))"
        case .oklch:
            let c = color.oklch
            let hue = c.hue.map { Self.decimal($0) } ?? "none"
            return "oklch(\(Self.decimal(c.lightness, precision: 5)) \(Self.decimal(c.chroma, precision: 5)) \(hue)\(alpha))"
        }
    }

    func parse(_ input: String, defaultAlpha: Double = 1) -> StudioColor? {
        if self == .hex { return StudioColor(hex: input) }
        var channels = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let opening = channels.firstIndex(of: "(") {
            guard channels.hasSuffix(")"), channels[..<opening].trimmingCharacters(in: .whitespaces) == rawValue.lowercased()
            else { return nil }
            channels = String(channels[channels.index(after: opening)..<channels.index(before: channels.endIndex)])
        }
        let parts = channels.split { $0.isWhitespace || $0 == "," || $0 == "/" }
        let baseCount = self == .cmyk ? 4 : 3
        guard parts.count == baseCount || parts.count == baseCount + 1 else { return nil }
        guard self != .rgba || parts.count == 4 else { return nil }

        func number(_ index: Int, range: ClosedRange<Double>, percentScale: Double? = nil, hue: Bool = false) -> Double? {
            var part = parts[index]
            if hue && part == "none" { return 0 }
            var multiplier = 1.0
            if part.hasSuffix("%") {
                guard let percentScale else { return nil }
                multiplier = percentScale / 100
                part = part.dropLast()
            } else if hue && part.hasSuffix("deg") {
                part = part.dropLast(3)
            } else if hue && part.hasSuffix("°") {
                part = part.dropLast()
            }
            guard let raw = Double(part), raw.isFinite, range.contains(raw * multiplier) else { return nil }
            return raw * multiplier
        }

        let alpha: Double
        if parts.count == baseCount + 1 {
            guard let opacity = number(baseCount, range: 0...1, percentScale: 1) else { return nil }
            alpha = opacity
        } else {
            alpha = defaultAlpha
        }

        switch self {
        case .hex: return nil
        case .rgb, .rgba:
            guard let r = number(0, range: 0...255, percentScale: 255),
                  let g = number(1, range: 0...255, percentScale: 255),
                  let b = number(2, range: 0...255, percentScale: 255) else { return nil }
            return StudioColor(red: r / 255, green: g / 255, blue: b / 255, alpha: alpha)
        case .hsl, .hsv:
            guard let hue = number(0, range: -Double.greatestFiniteMagnitude...Double.greatestFiniteMagnitude, hue: true),
                  let s = number(1, range: 0...100, percentScale: 100),
                  let level = number(2, range: 0...100, percentScale: 100) else { return nil }
            if self == .hsl { return StudioColor(hue: hue, saturation: s / 100, lightness: level / 100, alpha: alpha) }
            return StudioColor(hue: hue, saturation: s / 100, value: level / 100, alpha: alpha)
        case .cmyk:
            guard let c = number(0, range: 0...100, percentScale: 100),
                  let m = number(1, range: 0...100, percentScale: 100),
                  let y = number(2, range: 0...100, percentScale: 100),
                  let k = number(3, range: 0...100, percentScale: 100) else { return nil }
            return StudioColor(cyan: c / 100, magenta: m / 100, yellow: y / 100, key: k / 100, alpha: alpha)
        case .lab:
            guard let l = number(0, range: 0...100, percentScale: 100),
                  let a = number(1, range: -10000...10000, percentScale: 125),
                  let b = number(2, range: -10000...10000, percentScale: 125) else { return nil }
            return StudioColor(labLightness: l, a: a, b: b, alpha: alpha)
        case .lch:
            guard let l = number(0, range: 0...100, percentScale: 100),
                  let c = number(1, range: 0...10000, percentScale: 150),
                  let h = number(2, range: -Double.greatestFiniteMagnitude...Double.greatestFiniteMagnitude, hue: true) else { return nil }
            return StudioColor(lchLightness: l, chroma: c, hue: h, alpha: alpha)
        case .oklab:
            guard let l = number(0, range: 0...1, percentScale: 1),
                  let a = number(1, range: -100...100, percentScale: 0.4),
                  let b = number(2, range: -100...100, percentScale: 0.4) else { return nil }
            return StudioColor(oklabLightness: l, a: a, b: b, alpha: alpha)
        case .oklch:
            guard let l = number(0, range: 0...1, percentScale: 1),
                  let c = number(1, range: 0...100, percentScale: 0.4),
                  let h = number(2, range: -Double.greatestFiniteMagnitude...Double.greatestFiniteMagnitude, hue: true) else { return nil }
            return StudioColor(oklchLightness: l, chroma: c, hue: h, alpha: alpha)
        }
    }

    static func decimal(_ value: Double, precision: Int = 2) -> String {
        let threshold = pow(10, -Double(precision)) / 2
        var output = String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), precision,
                            abs(value) < threshold ? 0 : value)
        guard output.contains(".") else { return output }
        while output.last == "0" { output.removeLast() }
        if output.last == "." { output.removeLast() }
        return output
    }

    private static func percent(_ value: Double) -> String { decimal(value * 100) + "%" }
}

enum StudioCodeFormat: String, CaseIterable, Identifiable {
    case css = "CSS", cssVariable = "CSS variable", scss = "SCSS", swift = "Swift"
    case json = "JSON", xml = "XML", tailwind = "Tailwind", token = "Design token"
    var id: Self { self }

    func string(for color: StudioColor) -> String {
        let hex = color.displayHex
        switch self {
        case .css: return "color: \(hex);"
        case .cssVariable: return ":root {\n  --studio-color: \(hex);\n}"
        case .scss: return "$studio-color: \(hex);"
        case .swift:
            let values = [color.red, color.green, color.blue, color.alpha].map { StudioColorFormat.decimal($0, precision: 5) }
            return "import SwiftUI\n\nlet studioColor = Color(.sRGB, red: \(values[0]), green: \(values[1]), blue: \(values[2]), opacity: \(values[3]))"
        case .json: return "{\n  \"studioColor\": \"\(hex)\"\n}"
        case .xml: return "<color name=\"studio-color\">\(hex)</color>"
        case .tailwind: return "@theme {\n  --color-studio: \(hex);\n}"
        case .token:
            let channels = [color.red, color.green, color.blue].map { StudioColorFormat.decimal($0, precision: 6) }.joined(separator: ", ")
            let opacity = StudioColorFormat.decimal(color.alpha, precision: 6)
            return "{\n  \"studio-color\": {\n    \"$type\": \"color\",\n    \"$value\": {\n      \"colorSpace\": \"srgb\",\n      \"components\": [\(channels)],\n      \"alpha\": \(opacity),\n      \"hex\": \"\(color.hex)\"\n    }\n  }\n}"
        }
    }
}
