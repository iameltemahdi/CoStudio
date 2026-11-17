import SwiftUI

struct GradientStudioView: View {
    @State private var recipe = GradientPreset.citron.recipe
    @State private var export = CreativeExportDocument()
    @State private var exporting = false
    @State private var exportSVG = false
    @State private var errorMessage: String?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                WorkspaceHeader(
                    title: "Gradient Maker",
                    subtitle: "Adjust the angle, positions, and opacity of a live gradient.",
                    eyebrow: "Create"
                )
                options
                gradientPreview
                if recipe.kind == .linear { angleControls }
                stopEditor
                exportBar
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .padding(StudioTheme.padding)
            .frame(maxWidth: .infinity)
        }
        .fileExporter(
            isPresented: $exporting,
            document: export,
            contentType: exportSVG ? .svg : PaletteExport.css.contentType,
            defaultFilename: exportSVG ? "CoStudio Gradient.svg" : "CoStudio Gradient.css"
        ) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .alert("Gradient", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .onChange(of: recipe) { _, _ in copied = false }
    }

    private var options: some View {
        HStack(spacing: 12) {
            Picker("Gradient type", selection: $recipe.kind) {
                ForEach(StudioGradientKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            Spacer()
            Menu {
                ForEach(GradientPreset.allCases) { preset in
                    Button(preset.rawValue) { recipe = preset.recipe }
                }
            } label: {
                Label("Presets", systemImage: "swatchpalette")
            }
            .fixedSize()
        }
    }

    private var gradientPreview: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let height = max(1, proxy.size.height)
            let colors = recipe.sortedStops.map {
                Gradient.Stop(color: $0.color.swiftUIColor, location: $0.position)
            }
            let axis = recipe.axis(width: width, height: height)
            ColorCheckerboard(tile: 9)
                .overlay {
                    if recipe.kind == .linear {
                        LinearGradient(
                            stops: colors,
                            startPoint: UnitPoint(x: axis.start.x / width, y: axis.start.y / height),
                            endPoint: UnitPoint(x: axis.end.x / width, y: axis.end.y / height)
                        )
                    } else {
                        RadialGradient(stops: colors, center: .center, startRadius: 0, endRadius: min(width, height) / 2)
                    }
                }
        }
        .frame(height: 255)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1) }
        .accessibilityLabel("Gradient preview")
    }

    private var angleControls: some View {
        CreativePanel {
            HStack(spacing: 12) {
                Label("Angle", systemImage: "angle")
                    .font(.subheadline.weight(.medium))
                Slider(value: $recipe.angle, in: 0...360, step: 1) {
                    Text("Gradient angle")
                }
                Text("\(Int(recipe.angle))°")
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private var stopEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Color stops")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Add Stop", systemImage: "plus", action: addStop)
                    .buttonStyle(.bordered)
            }

            VStack(spacing: 0) {
                ForEach($recipe.stops) { $stop in
                    stopRow($stop)
                    if stop.id != recipe.stops.last?.id {
                        Divider().overlay(StudioTheme.line)
                    }
                }
            }
            .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1).allowsHitTesting(false) }
        }
    }

    private func stopRow(_ stop: Binding<StudioGradientStop>) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) {
                stopColorBar(stop)
                stopTrack(label: "Position", value: stop.position)
                stopTrack(label: "Opacity", value: opacityBinding(stop))
                removeButton(stop.wrappedValue.id)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    stopColorBar(stop)
                    Spacer()
                    removeButton(stop.wrappedValue.id)
                }
                stopTrack(label: "Position", value: stop.position)
                stopTrack(label: "Opacity", value: opacityBinding(stop))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
    }

    private func stopColorBar(_ stop: Binding<StudioGradientStop>) -> some View {
        HStack(spacing: 8) {
            CreativeColorControl(title: "Stop color", value: stop.color)
            CreativeHexField(value: stop.color)
                .frame(width: 102, alignment: .leading)
        }
        .fixedSize()
    }

    private func stopTrack(label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Slider(value: value, in: 0...1, step: 0.01) { Text(label) }
                .frame(minWidth: 95)
            Text("\(Int((value.wrappedValue * 100).rounded()))%")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func opacityBinding(_ stop: Binding<StudioGradientStop>) -> Binding<Double> {
        Binding(
            get: { stop.wrappedValue.color.alpha },
            set: { alpha in
                let value = stop.wrappedValue.color
                stop.wrappedValue.color = StudioColor(red: value.red, green: value.green, blue: value.blue, alpha: alpha)
            }
        )
    }

    private func removeButton(_ id: UUID) -> some View {
        Button(role: .destructive) {
            recipe.stops.removeAll { $0.id == id }
        } label: { Image(systemName: "minus.circle") }
            .buttonStyle(.borderless)
            .disabled(recipe.stops.count <= 2)
            .help("Remove stop")
            .accessibilityLabel("Remove stop")
    }

    private var exportBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSS")
                .font(.subheadline.weight(.semibold))
            Text(recipe.css)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 7))
                .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(StudioTheme.line, lineWidth: 1) }
            HStack(spacing: 10) {
                Button(copied ? "Copied CSS" : "Copy CSS", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    StudioClipboard.copy(recipe.css)
                    copied = true
                }
                .buttonStyle(.borderedProminent)
                Menu {
                    Button("CSS stylesheet") { beginExport(svg: false) }
                    Button("SVG image") { beginExport(svg: true) }
                } label: { Label("Export", systemImage: "square.and.arrow.up") }
            }
        }
    }

    private func addStop() {
        let sorted = recipe.sortedStops
        guard let first = sorted.first else { return }
        // Fill the largest gap, including any unoccupied space before and after the stops.
        let boundaryStops = [
            StudioGradientStop(color: first.color, position: 0)
        ] + sorted + [
            StudioGradientStop(color: sorted.last?.color ?? first.color, position: 1)
        ]
        let gaps = zip(boundaryStops, boundaryStops.dropFirst())
        guard let (start, end) = gaps.max(by: { ($0.1.position - $0.0.position) < ($1.1.position - $1.0.position) }) else { return }
        let color = StudioColor(
            red: (start.color.red + end.color.red) / 2,
            green: (start.color.green + end.color.green) / 2,
            blue: (start.color.blue + end.color.blue) / 2,
            alpha: (start.color.alpha + end.color.alpha) / 2
        )
        recipe.stops.append(StudioGradientStop(color: color, position: (start.position + end.position) / 2))
        recipe.stops = recipe.sortedStops
    }

    private func beginExport(svg: Bool) {
        let text = svg ? recipe.svg() : ":root {\n  --studio-gradient: \(recipe.css);\n}\n"
        exportSVG = svg
        export = CreativeExportDocument(data: Data(text.utf8))
        exporting = true
    }
}
