import Foundation

/// A bounded, non-premultiplied sRGB color. Alpha is independent of its RGB channels.
struct StudioColor: Codable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.unit(red)
        self.green = Self.unit(green)
        self.blue = Self.unit(blue)
        self.alpha = Self.unit(alpha)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let values = try [container.decode(Double.self, forKey: .red),
                          container.decode(Double.self, forKey: .green),
                          container.decode(Double.self, forKey: .blue),
                          container.decode(Double.self, forKey: .alpha)]
        guard values.allSatisfy({ (0...1).contains($0) }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Expected normalized RGBA channels."))
        }
        self.init(red: values[0], green: values[1], blue: values[2], alpha: values[3])
    }

    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard [3, 4, 6, 8].contains(digits.count),
              digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })
        else { return nil }
        if digits.count <= 4 { digits = digits.flatMap { [$0, $0] }.reduce(into: "") { $0.append($1) } }
        if digits.count == 6 { digits += "ff" }
        guard let packed = UInt32(digits, radix: 16) else { return nil }
        self.init(red: Double((packed >> 24) & 255) / 255,
                  green: Double((packed >> 16) & 255) / 255,
                  blue: Double((packed >> 8) & 255) / 255,
                  alpha: Double(packed & 255) / 255)
    }

    static let black = Self(red: 0, green: 0, blue: 0)
    static let white = Self(red: 1, green: 1, blue: 1)
    static let middleGray = Self(red: 0.5, green: 0.5, blue: 0.5)

    var rgb8: (red: Int, green: Int, blue: Int) {
        (Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    var hex: String { String(format: "#%02X%02X%02X", rgb8.red, rgb8.green, rgb8.blue) }
    var hexWithAlpha: String { hex + String(format: "%02X", Int((alpha * 255).rounded())) }
    var displayHex: String { alpha == 1 ? hex : hexWithAlpha }

    var hsv: (hue: Double, saturation: Double, value: Double) {
        let maximum = max(red, green, blue)
        let delta = maximum - min(red, green, blue)
        return (hue(maximum: maximum, delta: delta), maximum > 0 ? delta / maximum : 0, maximum)
    }

    var hsl: (hue: Double, saturation: Double, lightness: Double) {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let lightness = (maximum + minimum) / 2
        let denominator = 1 - abs(2 * lightness - 1)
        return (hue(maximum: maximum, delta: delta), delta > 0 && denominator > 0 ? Self.unit(delta / denominator) : 0, lightness)
    }

    init(hue: Double, saturation: Double, lightness: Double, alpha: Double = 1) {
        let lightness = Self.unit(lightness)
        let chroma = (1 - abs(2 * lightness - 1)) * Self.unit(saturation)
        self.init(hue: hue, chroma: chroma, offset: lightness - chroma / 2, alpha: alpha)
    }

    init(hue: Double, saturation: Double, value: Double, alpha: Double = 1) {
        let value = Self.unit(value)
        let chroma = value * Self.unit(saturation)
        self.init(hue: hue, chroma: chroma, offset: value - chroma, alpha: alpha)
    }

    private init(hue: Double, chroma: Double, offset: Double, alpha: Double) {
        let sector = Self.wrapHue(hue) / 60
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let rgb: (Double, Double, Double)
        switch Int(sector) {
        case 0: rgb = (chroma, x, 0)
        case 1: rgb = (x, chroma, 0)
        case 2: rgb = (0, chroma, x)
        case 3: rgb = (0, x, chroma)
        case 4: rgb = (x, 0, chroma)
        default: rgb = (chroma, 0, x)
        }
        self.init(red: rgb.0 + offset, green: rgb.1 + offset, blue: rgb.2 + offset, alpha: alpha)
    }

    private func hue(maximum: Double, delta: Double) -> Double {
        guard delta > 0 else { return 0 }
        if maximum == red { return Self.wrapHue(60 * (green - blue) / delta) }
        if maximum == green { return Self.wrapHue(60 * ((blue - red) / delta + 2)) }
        return Self.wrapHue(60 * ((red - green) / delta + 4))
    }

    /// Generic subtractive approximation. Device conversion requires an ICC profile.
    var cmyk: (cyan: Double, magenta: Double, yellow: Double, key: Double) {
        let value = max(red, green, blue)
        guard value > 0 else { return (0, 0, 0, 1) }
        return ((value - red) / value, (value - green) / value, (value - blue) / value, 1 - value)
    }

    init(cyan: Double, magenta: Double, yellow: Double, key: Double, alpha: Double = 1) {
        let value = 1 - Self.unit(key)
        self.init(red: (1 - Self.unit(cyan)) * value, green: (1 - Self.unit(magenta)) * value,
                  blue: (1 - Self.unit(yellow)) * value, alpha: alpha)
    }

    func withAlpha(_ opacity: Double) -> Self {
        Self(red: red, green: green, blue: blue, alpha: opacity)
    }

    /// Source-over compositing with sRGB components, matching the web contrast tool's preview.
    func composited(over background: Self) -> Self {
        let outputAlpha = alpha + background.alpha * (1 - alpha)
        guard outputAlpha > 0 else { return Self(red: 0, green: 0, blue: 0, alpha: 0) }
        let backWeight = background.alpha * (1 - alpha)
        return Self(red: (red * alpha + background.red * backWeight) / outputAlpha,
                    green: (green * alpha + background.green * backWeight) / outputAlpha,
                    blue: (blue * alpha + background.blue * backWeight) / outputAlpha,
                    alpha: outputAlpha)
    }

    func mixed(with other: Self, fraction: Double) -> Self {
        let fraction = Self.unit(fraction)
        let keep = 1 - fraction
        return Self(red: keep * red + fraction * other.red, green: keep * green + fraction * other.green,
                    blue: keep * blue + fraction * other.blue, alpha: keep * alpha + fraction * other.alpha)
    }

    static func unit(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }

    static func wrapHue(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        let positive = wrapped < 0 ? wrapped + 360 : wrapped
        return positive >= 360 ? 0 : positive
    }

    var linearRGB: SIMD3<Double> {
        SIMD3(Self.linearize(red), Self.linearize(green), Self.linearize(blue))
    }

    init(linearRGB: SIMD3<Double>, alpha: Double) {
        self.init(red: Self.encode(linearRGB.x), green: Self.encode(linearRGB.y),
                  blue: Self.encode(linearRGB.z), alpha: alpha)
    }

    private static func linearize(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    private static func encode(_ channel: Double) -> Double {
        channel <= 0.0031308 ? 12.92 * channel : 1.055 * pow(channel, 1 / 2.4) - 0.055
    }
}
