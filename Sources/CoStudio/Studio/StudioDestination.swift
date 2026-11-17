import SwiftUI

enum StudioDestination: String, CaseIterable, Identifiable, Hashable {
    case overview, picker, image, browse, palette, gradient, library, contrast, vision, science

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .picker: "Color Picker"
        case .image: "Image Studio"
        case .browse: "Color Library"
        case .palette: "Palette Generator"
        case .gradient: "Gradient Maker"
        case .library: "Projects & Collections"
        case .contrast: "Contrast Checker"
        case .vision: "Color Vision"
        case .science: "Color Science"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .picker: "eyedropper"
        case .image: "photo.on.rectangle"
        case .browse: "swatchpalette"
        case .palette: "rectangle.split.3x1"
        case .gradient: "circle.lefthalf.filled"
        case .library: "folder"
        case .contrast: "circle.righthalf.filled"
        case .vision: "eye"
        case .science: "function"
        }
    }

    var caption: String {
        switch self {
        case .overview: "Your studio at a glance."
        case .picker: "Set exact values and collect colors."
        case .image: "Sample, edit, and recolor your images."
        case .browse: "Explore named colors and related hues."
        case .palette: "Build harmonies and lock your favorites."
        case .gradient: "Shape color stops and export a gradient."
        case .library: "Keep palettes, projects, and collections in one place."
        case .contrast: "Check text against WCAG targets."
        case .vision: "Preview how different eyes see a color."
        case .science: "Convert color spaces and inspect relationships."
        }
    }

    var shortcut: KeyEquivalent {
        KeyEquivalent(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"][Self.allCases.firstIndex(of: self) ?? 0].first ?? "1")
    }
}

enum StudioSection: String, CaseIterable, Identifiable {
    case pick = "Pick colors"
    case create = "Create"
    case check = "Check & analyze"

    var id: Self { self }
    var destinations: [StudioDestination] {
        switch self {
        case .pick: [.picker, .image, .browse]
        case .create: [.palette, .gradient, .library]
        case .check: [.contrast, .vision, .science]
        }
    }
}
