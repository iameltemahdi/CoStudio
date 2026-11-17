import SwiftUI

struct ImageInspector: View {
    let model: ImageWorkspaceModel
    @Binding var tool: ImageWorkspaceTool
    @Binding var crop: ImageCrop
    let palettes: [StudioPalette]
    let comparing: Bool
    let useColor: (StudioColor) -> Void
    let savePalette: ([StudioColor]) -> Void

    @State private var extractCount = 6
    @State private var target = StudioColor(red: 0.61, green: 0.71, blue: 0.43)
    @State private var tolerance = 0.17
    @State private var selectedPalette: UUID?
    @State private var paletteMode: PaletteMode = .multiple
    @State private var paletteIntensity = 0.8
    @State private var background: BackgroundMode = .transparent
    @State private var backgroundFirst = StudioColor(red: 0.93, green: 0.91, blue: 0.84)
    @State private var backgroundLast = StudioColor(red: 0.46, green: 0.53, blue: 0.34)

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Picker("Image tool", selection: $tool) {
                ForEach(ImageWorkspaceTool.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon).tag(item)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Image tool")
            .frame(maxWidth: .infinity)
            .disabled(model.busy)

            Rectangle().fill(StudioTheme.line).frame(height: 1)

            if model.preview != nil {
                previewActions
            } else if comparing {
                Text("Showing the original image. Select Show Edit to continue.")
                    .foregroundStyle(.secondary)
            } else {
                toolControls
                    .disabled(model.busy)
            }
        }
        .font(.callout)
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1) }
    }

    @ViewBuilder
    private var toolControls: some View {
        switch tool {
        case .sample: sampleTool
        case .crop: cropTool
        case .replace: replaceTool
        case .palette: paletteTool
        case .background: backgroundTool
        }
    }

    private var previewActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edit preview")
                .font(.headline)
            Text("Apply to save this change to the image’s edit history.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Apply Edit") { model.commitPreview() }
                    .buttonStyle(.borderedProminent)
                Button("Discard") { model.discardPreview() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var sampleTool: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let color = model.pickedColor {
                sampledColor(color)
                HStack(spacing: 6) {
                    Button("Use in Studio") { useColor(color) }
                        .buttonStyle(.borderedProminent)
                    Button("Save Color") { savePalette([color]) }
                        .buttonStyle(.bordered)
                }
            } else {
                Text("Click or tap a pixel to see its color.")
                    .foregroundStyle(.secondary)
            }

            Rectangle().fill(StudioTheme.line).frame(height: 1)

            Text("Dominant colors").font(.headline)
            Stepper("Palette size: \(extractCount)", value: $extractCount, in: 2...12)
            Button("Extract Palette", systemImage: "sparkle.magnifyingglass") {
                Task { await model.extract(extractCount) }
            }
            .buttonStyle(.bordered)

            if !model.extractedColors.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 27), spacing: 4)], spacing: 4) {
                    ForEach(Array(model.extractedColors.enumerated()), id: \.offset) { _, color in
                        Button {
                            StudioClipboard.copy(color.displayHex)
                            model.status = "Copied \(color.displayHex)."
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color.swiftUIColor)
                                .frame(height: 28)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.16)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copy \(color.displayHex)")
                        .help("Copy \(color.displayHex)")
                    }
                }
                Button("Save Palette", systemImage: "plus") { savePalette(model.extractedColors) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func sampledColor(_ color: StudioColor) -> some View {
        HStack(spacing: 9) {
            if let loupe = model.loupe {
                Image(decorative: loupe, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .background { ColorCheckerboard(tile: 5) }
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(StudioTheme.line))
                    .accessibilityLabel("Magnified pixel area")
            }
            VStack(alignment: .leading, spacing: 3) {
                Button {
                    StudioClipboard.copy(color.displayHex)
                    model.status = "Copied \(color.displayHex)."
                } label: {
                    Label(color.displayHex, systemImage: "doc.on.doc")
                        .lineLimit(1)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy \(color.displayHex)")
                if let position = model.pickedPosition {
                    Text("X \(Int(position.x))   Y \(Int(position.y))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4)
                .fill(color.swiftUIColor)
                .background { ColorCheckerboard(tile: 5).clipShape(RoundedRectangle(cornerRadius: 4)) }
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(StudioTheme.line))
                .frame(width: 19, height: 19)
                .accessibilityHidden(true)
        }
    }

    private var cropTool: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Crop area").font(.headline)
            Text("Drag a rectangle on the image, or edit its edges below.")
                .foregroundStyle(.secondary)
            cropEdge("Left", value: $crop.left)
            cropEdge("Top", value: $crop.top)
            cropEdge("Right", value: $crop.right)
            cropEdge("Bottom", value: $crop.bottom)
            HStack {
                Button("Apply Crop") {
                    let selection = crop
                    crop = .whole
                    Task { await model.apply(.crop(selection)) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(crop == .whole || crop.right <= crop.left || crop.bottom <= crop.top)
                Button("Reset") { crop = .whole }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func cropEdge(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .percent.precision(.fractionLength(1)))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .frame(width: 74)
                .onSubmit { value.wrappedValue = min(1, max(0, value.wrappedValue)) }
                .accessibilityLabel("\(title) crop edge")
        }
    }

    private var replaceTool: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Color replacement").font(.headline)
            if let source = model.pickedColor {
                sampledColor(source)
            } else {
                Text("Click or tap the color you want to replace.")
                    .foregroundStyle(.secondary)
            }
            ImageColorField(label: "Replacement", value: $target, supportsOpacity: false)
            percentageControl("Tolerance", value: $tolerance)
            Button("Preview Replacement") {
                guard let source = model.pickedColor else { return }
                let edit = ImageEdit.replace(source: source, target: target, tolerance: tolerance)
                Task { await model.showPreview(edit) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.pickedColor == nil)
        }
    }

    private var paletteTool: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Palette mapping").font(.headline)
            if palettes.isEmpty {
                Text("Save a palette in the library or extract one from this image to use it here.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Palette", selection: $selectedPalette) {
                    Text("Choose a palette").tag(UUID?.none)
                    ForEach(palettes) { palette in Text(palette.name).tag(Optional(palette.id)) }
                }
                Picker("Effect", selection: $paletteMode) {
                    Text("Duotone").tag(PaletteMode.duotone)
                    Text("Multicolor").tag(PaletteMode.multiple)
                }
                percentageControl("Intensity", value: $paletteIntensity)
                if let colors = selectedColors {
                    HStack(spacing: 1) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                            Rectangle().fill(color.swiftUIColor)
                        }
                    }
                    .frame(height: 15)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .accessibilityLabel("Palette ordered from shadows to highlights")
                    if colors.count < 2 {
                        Text("Choose a palette with at least two colors.")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Preview Palette") {
                    guard let colors = selectedColors else { return }
                    let edit = ImageEdit.palette(colors, intensity: paletteIntensity)
                    Task { await model.showPreview(edit) }
                }
                .buttonStyle(.borderedProminent)
                .disabled((selectedColors?.count ?? 0) < 2)
            }
        }
    }

    private var selectedColors: [StudioColor]? {
        guard let matching = palettes.first(where: { $0.id == selectedPalette }) else { return nil }
        let sorted = matching.hexColors.compactMap(StudioColor.init(hex:))
            .sorted { brightness($0) < brightness($1) }
        if paletteMode == .duotone, let first = sorted.first, let last = sorted.last, sorted.count > 1 {
            return [first, last]
        }
        return sorted
    }

    private func brightness(_ color: StudioColor) -> Double {
        0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
    }

    private var backgroundTool: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Subject isolation").font(.headline)
            Text("Vision identifies foreground subjects on this device.")
                .foregroundStyle(.secondary)
            Picker("Background", selection: $background) {
                Text("Transparent").tag(BackgroundMode.transparent)
                Text("Solid").tag(BackgroundMode.solid)
                Text("Gradient").tag(BackgroundMode.gradient)
            }
            if background != .transparent {
                ImageColorField(
                    label: background == .solid ? "Fill" : "Start color",
                    value: $backgroundFirst, supportsOpacity: true
                )
            }
            if background == .gradient {
                ImageColorField(label: "End color", value: $backgroundLast, supportsOpacity: true)
            }
            Button("Preview Cutout", systemImage: "person.crop.rectangle") {
                let fill: ImageBackground
                switch background {
                case .transparent: fill = .transparent
                case .solid: fill = .solid(backgroundFirst)
                case .gradient: fill = .gradient(backgroundFirst, backgroundLast)
                }
                Task { await model.showPreview(.isolate(fill)) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func percentageControl(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) {
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.caption, design: .monospaced))
            }
            Slider(value: value, in: 0...1)
                .accessibilityLabel(title)
        }
    }

    private enum PaletteMode { case duotone, multiple }
    private enum BackgroundMode { case transparent, solid, gradient }
}

private struct ImageColorField: View {
    let label: String
    @Binding var value: StudioColor
    let supportsOpacity: Bool
    @Environment(\.self) private var environment

    var body: some View {
        ColorPicker(label, selection: Binding(
            get: { value.swiftUIColor },
            set: { selected in
                let resolved = StudioColor(swiftUIColor: selected, environment: environment)
                value = supportsOpacity ? resolved : resolved.withAlpha(1)
            }
        ), supportsOpacity: supportsOpacity)
    }
}
