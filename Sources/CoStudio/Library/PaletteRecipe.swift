import Foundation

enum PaletteHarmony: String, CaseIterable, Identifiable {
    case random = "Random"
    case monochromatic = "Monochromatic"
    case complementary = "Complementary"
    case analogous = "Analogous"
    case triadic = "Triadic"
    case tetradic = "Tetradic"
    case splitComplementary = "Split complementary"

    var id: Self { self }

    private var hueOffsets: [Double] {
        switch self {
        case .random, .monochromatic: [0]
        case .complementary: [0, 180]
        case .analogous: [0, -24, 24, -48, 48]
        case .triadic: [0, 120, 240]
        case .tetradic: [0, 90, 180, 270]
        case .splitComplementary: [0, 150, 210]
        }
    }

    func generate<R: RandomNumberGenerator>(
        colors: [StudioColor], locked: Set<Int>, using generator: inout R
    ) -> [StudioColor] {
        let offsets = hueOffsets
        let anchorIndex = colors.indices.first { locked.contains($0) }
        let anchor = anchorIndex.map { colors[$0].hsl }
        let anchorOffset = anchorIndex.map { offsets[$0 % offsets.count] } ?? 0
        let baseHue = anchor.map { $0.hue - anchorOffset } ?? Double.random(in: 0..<360, using: &generator)
        let baseSaturation = anchor.map { max($0.saturation, 0.28) } ?? Double.random(in: 0.48...0.76, using: &generator)

        return colors.indices.map { index in
            guard !locked.contains(index) else { return colors[index] }
            if self == .random {
                return StudioColor(
                    hue: Double.random(in: 0..<360, using: &generator),
                    saturation: Double.random(in: 0.34...0.88, using: &generator),
                    lightness: Double.random(in: 0.27...0.82, using: &generator)
                )
            }
            let fraction = Double(index) / Double(max(colors.count - 1, 1))
            let lightness = self == .monochromatic ? 0.22 + fraction * 0.61 : [0.34, 0.51, 0.69, 0.43, 0.81][index % 5]
            return StudioColor(
                hue: baseHue + offsets[index % offsets.count],
                saturation: min(1, baseSaturation * (0.84 + fraction * 0.18)),
                lightness: lightness
            )
        }
    }
}

struct PaletteSwatch: Identifiable, Equatable {
    let id: UUID
    var color: StudioColor
    var isLocked = false

    init(_ color: StudioColor) {
        self.id = UUID()
        self.color = color
    }
}
