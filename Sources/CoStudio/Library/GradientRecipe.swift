import Foundation

enum StudioGradientKind: String, CaseIterable, Identifiable {
    case linear = "Linear"
    case radial = "Radial"
    var id: Self { self }
}

struct StudioGradientStop: Identifiable, Equatable {
    let id = UUID()
    var color: StudioColor
    var position: Double
}

struct GradientRecipe: Equatable {
    var kind: StudioGradientKind = .linear
    var angle = 112.0
    var stops: [StudioGradientStop]

    var sortedStops: [StudioGradientStop] {
        stops.sorted { $0.position < $1.position }
    }

    /// CSS angles progress clockwise, with zero pointing up.
    func axis(width: Double, height: Double) -> (start: CGPoint, end: CGPoint) {
        let radians = angle * .pi / 180
        let dx = sin(radians)
        let dy = -cos(radians)
        let halfLength = (abs(dx) * width + abs(dy) * height) / 2
        let offsetX = dx * halfLength
        let offsetY = dy * halfLength
        return (
            CGPoint(x: width / 2 - offsetX, y: height / 2 - offsetY),
            CGPoint(x: width / 2 + offsetX, y: height / 2 + offsetY)
        )
    }

    var css: String {
        let stops = sortedStops.map {
            "\($0.color.exportHex) \(creativeDecimal($0.position * 100, precision: 1))%"
        }.joined(separator: ", ")
        switch kind {
        case .linear: return "linear-gradient(\(creativeDecimal(angle, precision: 1))deg, \(stops))"
        case .radial: return "radial-gradient(circle closest-side at center, \(stops))"
        }
    }

    func svg(width: Double = 960, height: Double = 540) -> String {
        let bounds = "\(creativeDecimal(width)) \(creativeDecimal(height))"
        let element: String
        let attributes: String
        switch kind {
        case .linear:
            let points = axis(width: width, height: height)
            element = "linearGradient"
            attributes = "x1=\"\(creativeDecimal(points.start.x))\" y1=\"\(creativeDecimal(points.start.y))\" x2=\"\(creativeDecimal(points.end.x))\" y2=\"\(creativeDecimal(points.end.y))\""
        case .radial:
            element = "radialGradient"
            attributes = "cx=\"\(creativeDecimal(width / 2))\" cy=\"\(creativeDecimal(height / 2))\" r=\"\(creativeDecimal(min(width, height) / 2))\""
        }
        let stopNodes = sortedStops.map {
            "      <stop offset=\"\(creativeDecimal($0.position))\" stop-color=\"\($0.color.hex)\" stop-opacity=\"\(creativeDecimal($0.color.alpha))\"/>"
        }.joined(separator: "\n")
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(bounds)">
          <defs>
            <\(element) id="gradient" gradientUnits="userSpaceOnUse" \(attributes)>
        \(stopNodes)
            </\(element)>
          </defs>
          <rect width="100%" height="100%" fill="url(#gradient)"/>
        </svg>

        """
    }
}

enum GradientPreset: String, CaseIterable, Identifiable {
    case citron = "Citron"
    case blueHour = "Blue Hour"
    case clay = "Clay"
    case forest = "Forest"
    case graphite = "Graphite"

    var id: Self { self }

    var recipe: GradientRecipe {
        let values: [String]
        switch self {
        case .citron: values = ["#253326", "#7C933E", "#E2D97D"]
        case .blueHour: values = ["#171D3D", "#4B5EA1", "#B6BFE8"]
        case .clay: values = ["#52241F", "#B96C5B", "#F3C899"]
        case .forest: values = ["#152D2A", "#2A6554", "#9DAA7A"]
        case .graphite: values = ["#252522", "#5A5C55", "#BDBFB3"]
        }
        let colorStops = values.enumerated().compactMap { index, value in
            StudioColor(hex: value).map { StudioGradientStop(color: $0, position: Double(index) / 2) }
        }
        return GradientRecipe(stops: colorStops)
    }
}
