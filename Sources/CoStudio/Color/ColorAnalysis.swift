import Foundation
import simd

extension StudioColor {
    // CSS Color 4: https://www.w3.org/TR/css-color-4/#color-conversion-code
    // Linear sRGB to XYZ followed by Bradford D65 to D50 adaptation.
    private static let d50FromRGB = simd_double3x3(rows: [
        SIMD3(0.4360657469, 0.3851515096, 0.1430784199),
        SIMD3(0.2224931771, 0.7168870131, 0.0606198099),
        SIMD3(0.0139239215, 0.0970813242, 0.7140993568)
    ])
    private static let d50White = SIMD3(0.3457 / 0.3585, 1.0, (1 - 0.3457 - 0.3585) / 0.3585)
    private static let rgbFromD50 = d50FromRGB.inverse
    // Oklab's original sRGB transform: https://bottosson.github.io/posts/oklab/
    private static let rgbToLMS = simd_double3x3(rows: [
        SIMD3(0.4122214708, 0.5363325363, 0.0514459929),
        SIMD3(0.2119034982, 0.6806995451, 0.1073969566),
        SIMD3(0.0883024619, 0.2817188376, 0.6299787005)
    ])
    private static let lmsToOKLab = simd_double3x3(rows: [
        SIMD3(0.2104542553, 0.7936177850, -0.0040720468),
        SIMD3(1.9779984951, -2.4285922050, 0.4505937099),
        SIMD3(0.0259040371, 0.7827717662, -0.8086757660)
    ])
    private static let lmsToRGB = rgbToLMS.inverse
    private static let okLabToLMS = lmsToOKLab.inverse
    private static let cieEpsilon = 216.0 / 24389
    private static let cieKappa = 24389.0 / 27

    var lab: (lightness: Double, a: Double, b: Double) {
        let xyz = (Self.d50FromRGB * linearRGB) / Self.d50White
        func transfer(_ value: Double) -> Double {
            value > Self.cieEpsilon ? cbrt(value) : (Self.cieKappa * value + 16) / 116
        }
        let x = transfer(xyz.x), y = transfer(xyz.y), z = transfer(xyz.z)
        return (116 * y - 16, 500 * (x - y), 200 * (y - z))
    }

    init(labLightness lightness: Double, a: Double, b: Double, alpha: Double = 1) {
        let y = (min(100, max(0, lightness)) + 16) / 116
        func inverseTransfer(_ value: Double) -> Double {
            let cube = value * value * value
            return cube > Self.cieEpsilon ? cube : (116 * value - 16) / Self.cieKappa
        }
        let xyz = SIMD3(inverseTransfer(y + a / 500), inverseTransfer(y), inverseTransfer(y - b / 200))
        self.init(linearRGB: Self.rgbFromD50 * (xyz * Self.d50White), alpha: alpha)
    }

    var lch: (lightness: Double, chroma: Double, hue: Double?) {
        let c = lab
        let chroma = hypot(c.a, c.b)
        return (c.lightness, chroma, chroma <= 0.0015 ? nil : Self.wrapHue(atan2(c.b, c.a) * 180 / .pi))
    }

    init(lchLightness lightness: Double, chroma: Double, hue: Double, alpha: Double = 1) {
        let angle = Self.wrapHue(hue) * .pi / 180
        self.init(labLightness: lightness, a: max(0, chroma) * cos(angle), b: max(0, chroma) * sin(angle), alpha: alpha)
    }

    var oklab: (lightness: Double, a: Double, b: Double) {
        let lms = Self.rgbToLMS * linearRGB
        let lab = Self.lmsToOKLab * SIMD3(cbrt(lms.x), cbrt(lms.y), cbrt(lms.z))
        return (lab.x, lab.y, lab.z)
    }

    init(oklabLightness lightness: Double, a: Double, b: Double, alpha: Double = 1) {
        let lmsRoot = Self.okLabToLMS * SIMD3(Self.unit(lightness), a, b)
        self.init(linearRGB: Self.lmsToRGB * (lmsRoot * lmsRoot * lmsRoot), alpha: alpha)
    }

    var oklch: (lightness: Double, chroma: Double, hue: Double?) {
        let c = oklab
        let chroma = hypot(c.a, c.b)
        return (c.lightness, chroma, chroma <= 0.000004 ? nil : Self.wrapHue(atan2(c.b, c.a) * 180 / .pi))
    }

    init(oklchLightness lightness: Double, chroma: Double, hue: Double, alpha: Double = 1) {
        let angle = Self.wrapHue(hue) * .pi / 180
        self.init(oklabLightness: lightness, a: max(0, chroma) * cos(angle), b: max(0, chroma) * sin(angle), alpha: alpha)
    }

    func perceptualDistance(to other: Self) -> Double {
        let lhs = oklab, rhs = other.oklab
        return hypot(hypot(lhs.lightness - rhs.lightness, lhs.a - rhs.a), lhs.b - rhs.b)
    }

    /// A hue-family description. RGB swatches do not encode a light source's CCT.
    var hueTemperature: String {
        let hsl = hsl
        if hsl.saturation < 0.08 || oklch.chroma < 0.015 { return "Neutral" }
        switch hsl.hue {
        case 0..<85, 320..<360: return "Warm"
        case 95..<305: return "Cool"
        default: return "Balanced"
        }
    }

    func hueRotated(by degrees: Double) -> Self {
        let channels = hsl
        return Self(hue: channels.hue + degrees, saturation: channels.saturation,
                    lightness: channels.lightness, alpha: alpha)
    }

    // WCAG 2.2 relative luminance: https://www.w3.org/TR/WCAG22/#dfn-relative-luminance
    var relativeLuminance: Double { simd_dot(linearRGB, SIMD3(0.2126, 0.7152, 0.0722)) }
}

enum ColorVariation: String, CaseIterable, Identifiable {
    case tints = "Tints", shades = "Shades", tones = "Tones", lightness = "Lightness", saturation = "Saturation"
    var id: Self { self }
    func colors(from source: StudioColor) -> [StudioColor] {
        let hsl = source.hsl
        return (1...7).map { index in
            let fraction = Double(index) / 8
            switch self {
            case .tints: return source.mixed(with: StudioColor.white.withAlpha(source.alpha), fraction: fraction)
            case .shades: return source.mixed(with: StudioColor.black.withAlpha(source.alpha), fraction: fraction)
            case .tones: return source.mixed(with: StudioColor.middleGray.withAlpha(source.alpha), fraction: fraction)
            case .lightness:
                return StudioColor(hue: hsl.hue, saturation: hsl.saturation, lightness: fraction, alpha: source.alpha)
            case .saturation:
                return StudioColor(hue: hsl.hue, saturation: fraction, lightness: hsl.lightness, alpha: source.alpha)
            }
        }
    }
}

enum ColorHarmony: String, CaseIterable, Identifiable {
    case complementary = "Complementary", analogous = "Analogous", triadic = "Triadic"
    case tetradic = "Tetradic", splitComplementary = "Split complementary", monochromatic = "Monochromatic"
    var id: Self { self }
    func colors(from source: StudioColor) -> [StudioColor] {
        let offsets: [Double]
        switch self {
        case .complementary: offsets = [0, 180]
        case .analogous: offsets = [-30, 0, 30]
        case .triadic: offsets = [0, 120, 240]
        case .tetradic: offsets = [0, 60, 180, 240]
        case .splitComplementary: offsets = [0, 150, 210]
        case .monochromatic:
            let hsl = source.hsl
            return [0.18, 0.34, 0.5, 0.66, 0.82].map {
                StudioColor(hue: hsl.hue, saturation: hsl.saturation, lightness: $0, alpha: source.alpha)
            }
        }
        return offsets.map { source.hueRotated(by: $0) }
    }
}

struct ContrastReport {
    let renderedForeground: StudioColor
    let renderedBackground: StudioColor

    init(foreground: StudioColor, background: StudioColor, canvas: StudioColor = .white) {
        renderedBackground = background.composited(over: canvas.withAlpha(1))
        renderedForeground = foreground.composited(over: renderedBackground)
    }

    var ratio: Double {
        let foreground = renderedForeground.relativeLuminance
        let background = renderedBackground.relativeLuminance
        return (max(foreground, background) + 0.05) / (min(foreground, background) + 0.05)
    }

    enum Criterion: String, CaseIterable, Identifiable {
        case normalAA, normalAAA, largeAA, largeAAA
        var id: Self { self }
        var title: String { self == .normalAA || self == .largeAA ? "AA" : "AAA" }
        var size: String { self == .normalAA || self == .normalAAA ? "Normal text" : "Large text" }
        var threshold: Double {
            switch self {
            case .normalAA, .largeAAA: return 4.5
            case .normalAAA: return 7
            case .largeAA: return 3
            }
        }
    }

    func passes(_ criterion: Criterion) -> Bool { ratio >= criterion.threshold }

    static func suggestions(foreground: StudioColor, background: StudioColor, threshold: Double) -> [StudioColor] {
        func ratio(_ color: StudioColor) -> Double {
            Self(foreground: color, background: background).ratio
        }
        guard ratio(foreground) < threshold else { return [] }
        let channels = foreground.hsl
        let candidates: [StudioColor] = [0.0, 1.0].compactMap { extreme in
            func color(_ amount: Double) -> StudioColor {
                let continuous = StudioColor(hue: channels.hue, saturation: channels.saturation,
                                             lightness: channels.lightness + (extreme - channels.lightness) * amount,
                                             alpha: foreground.alpha)
                // The displayed/copyable RGB hex should meet the same threshold.
                let rgb = continuous.rgb8
                return StudioColor(red: Double(rgb.red) / 255, green: Double(rgb.green) / 255,
                                   blue: Double(rgb.blue) / 255, alpha: foreground.alpha)
            }
            guard ratio(color(1)) >= threshold else { return nil }
            var lower = 0.0, upper = 1.0
            for _ in 0..<22 {
                let middle = (lower + upper) / 2
                if ratio(color(middle)) >= threshold { upper = middle } else { lower = middle }
            }
            return color(upper)
        }
        return candidates.sorted { foreground.perceptualDistance(to: $0) < foreground.perceptualDistance(to: $1) }
    }
}

enum ColorVisionMode: String, CaseIterable, Identifiable {
    case protanopia = "Protanopia"
    case deuteranopia = "Deuteranopia"
    case tritanopia = "Tritanopia"
    case achromatopsia = "Achromatopsia"
    var id: Self { self }

    var description: String {
        switch self {
        case .protanopia: return "Red and green distinctions change with absent L-cone response."
        case .deuteranopia: return "Red and green distinctions change with absent M-cone response."
        case .tritanopia: return "Blue and yellow distinctions change with absent S-cone response."
        case .achromatopsia: return "A luminance-based grayscale approximation of complete color loss."
        }
    }

    func simulate(_ color: StudioColor) -> StudioColor {
        // Machado, Oliveira and Fernandes, IEEE TVCG (2009), DOI 10.1109/TVCG.2009.113.
        // Full-severity endpoint matrices applied to linear sRGB.
        let rows: [SIMD3<Double>]
        switch self {
        case .protanopia:
            rows = [SIMD3(0.152286, 1.052583, -0.204868), SIMD3(0.114503, 0.786281, 0.099216), SIMD3(-0.003882, -0.048116, 1.051998)]
        case .deuteranopia:
            rows = [SIMD3(0.367322, 0.860646, -0.227968), SIMD3(0.280085, 0.672501, 0.047413), SIMD3(-0.011820, 0.042940, 0.968881)]
        case .tritanopia:
            rows = [SIMD3(1.255528, -0.076749, -0.178779), SIMD3(-0.078411, 0.930809, 0.147602), SIMD3(0.004733, 0.691367, 0.303900)]
        case .achromatopsia:
            return StudioColor(linearRGB: SIMD3(repeating: color.relativeLuminance), alpha: color.alpha)
        }
        return StudioColor(linearRGB: simd_double3x3(rows: rows) * color.linearRGB, alpha: color.alpha)
    }
}
