import SwiftUI

struct ColorPickerWorkspace: View {
    @Binding var selection: StudioColor
    @State private var colorModel: StudioColorFormat = .rgb
    @State private var harmony: ColorHarmony = .analogous
    @State private var hue: Double = 40
    @State private var rememberedSaturation = 0.6
    @State private var rememberedHSLSaturation = 0.6
    @AppStorage("colorPicker.history.v1") private var storedHistory = Data()
    @AppStorage("colorPicker.favorites.v1") private var storedFavorites = Data()

    private static let hueStops = stride(from: 0.0, through: 360.0, by: 60).map {
        StudioColor(hue: $0, saturation: 1, value: 1).swiftUIColor
    }

    private var history: [StudioColor] { decode(storedHistory) }
    private var favorites: [StudioColor] { decode(storedFavorites) }
    private var isFavorite: Bool { favorites.contains { $0.displayHex == selection.displayHex } }

    var body: some View {
        ColorStudioPage(title: "Color Picker", subtitle: "Pick, refine, and copy precise color values.", section: "PICK COLORS") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    colorCanvas.frame(minWidth: 266, maxWidth: .infinity)
                    inspector.frame(width: 255)
                }
                VStack(spacing: 20) { colorCanvas; inspector }
            }

            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    StudioSectionTitle(title: "Color combinations")
                    Spacer()
                    Picker("Harmony", selection: $harmony) {
                        ForEach(ColorHarmony.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                ColorSwatchLine(colors: harmony.colors(from: selection)) { selection = $0 }
            }

            Divider()
            swatchGroup("Favorites", colors: favorites, empty: "Use the star to keep a color.")
            swatchGroup("Recent colors", colors: history, empty: "Colors you use appear here.")
        }
        .onChange(of: selection, initial: true) { _, color in
            let channels = color.hsv
            if channels.saturation > 0.00001 { hue = channels.hue }
            if channels.value > 0.00001 { rememberedSaturation = channels.saturation }
            let hsl = color.hsl
            if (0.00001..<0.99999).contains(hsl.lightness) { rememberedHSLSaturation = hsl.saturation }
        }
        .task(id: selection) {
            let settled = selection
            do {
                try await Task.sleep(for: .milliseconds(380))
                guard history.first?.displayHex != settled.displayHex else { return }
                let updated = [settled] + history.filter { $0.displayHex != settled.displayHex }
                storedHistory = encode(Array(updated.prefix(24)))
            } catch { /* An in-progress color edit replaced this selection. */ }
        }
    }

    private var colorCanvas: some View {
        VStack(alignment: .leading, spacing: 15) {
            saturationField
                .frame(height: 250)
            VStack(spacing: 13) {
                colorTrack("Hue", value: Binding(get: { hue / 360 }, set: { setHue($0 * 360) }),
                           gradient: LinearGradient(colors: Self.hueStops,
                                                    startPoint: .leading, endPoint: .trailing),
                           valueLabel: "\(Int(hue.rounded()))°")
                colorTrack("Opacity", value: Binding(get: { selection.alpha }, set: { selection = selection.withAlpha($0) }),
                           gradient: LinearGradient(colors: [selection.withAlpha(0).swiftUIColor, selection.withAlpha(1).swiftUIColor],
                                                    startPoint: .leading, endPoint: .trailing),
                           valueLabel: "\(Int((selection.alpha * 100).rounded()))%",
                           checkerboard: true)
            }
        }
    }

    private var saturationField: some View {
        GeometryReader { geometry in
            let shape = RoundedRectangle(cornerRadius: 8)
            let size = geometry.size
            let channels = selection.hsv
            let x = channels.value == 0 ? rememberedSaturation : channels.saturation
            let y = 1 - channels.value
            let hueColor = StudioColor(hue: hue, saturation: 1, value: 1).swiftUIColor

            ZStack {
                shape.fill(hueColor)
                shape.fill(LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .leading, endPoint: .trailing))
                shape.fill(LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(.black.opacity(0.18), lineWidth: 1)
                Circle()
                    .fill(selection.withAlpha(1).swiftUIColor)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.55), radius: 2)
                    .frame(width: 19, height: 19)
                    .position(x: 8 + x * max(0, size.width - 16), y: 8 + y * max(0, size.height - 16))
            }
            .contentShape(shape)
            .gesture(DragGesture(minimumDistance: 0).onChanged { event in
                guard size.width > 16, size.height > 16 else { return }
                let saturation = StudioColor.unit((event.location.x - 8) / (size.width - 16))
                let value = 1 - StudioColor.unit((event.location.y - 8) / (size.height - 16))
                rememberedSaturation = saturation
                selection = StudioColor(hue: hue, saturation: saturation, value: value, alpha: selection.alpha)
            })
            .accessibilityHidden(true)
        }
    }

    private func colorTrack(_ label: String, value: Binding<Double>, gradient: LinearGradient, valueLabel: String,
                            checkerboard: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.caption.weight(.medium)).frame(width: 47, alignment: .leading)
            GeometryReader { geometry in
                let width = geometry.size.width
                let shape = RoundedRectangle(cornerRadius: 5)
                ZStack {
                    if checkerboard { ColorCheckerboard(tile: 5).clipShape(shape) }
                    shape.fill(gradient)
                    shape.strokeBorder(StudioTheme.line, lineWidth: 1)
                    Circle()
                        .fill(.white)
                        .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 1))
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                        .frame(width: 13, height: 13)
                        .position(x: 6.5 + value.wrappedValue * max(0, width - 13), y: geometry.size.height / 2)
                }
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { event in
                    guard width > 13 else { return }
                    value.wrappedValue = StudioColor.unit((event.location.x - 6.5) / (width - 13))
                })
            }
            .frame(height: 18)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(valueLabel)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value.wrappedValue = StudioColor.unit(value.wrappedValue + 0.01)
                case .decrement: value.wrappedValue = StudioColor.unit(value.wrappedValue - 0.01)
                @unknown default: break
                }
            }
            Text(valueLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CURRENT COLOR")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove favorite" : "Favorite color")
                .help(isFavorite ? "Remove favorite" : "Favorite color")
            }
            ColorFilm(color: selection).frame(height: 63)

            HStack(spacing: 5) {
                StudioColorInput(label: "Current color", color: $selection)
                ColorCopyButton(value: selection.displayHex, title: "Copy HEX", compact: true)
                    .buttonStyle(.borderless)
            }

            Divider()

            Picker("Color model", selection: $colorModel) {
                Text("RGB").tag(StudioColorFormat.rgb)
                Text("HSL").tag(StudioColorFormat.hsl)
                Text("HSV").tag(StudioColorFormat.hsv)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            sliders

            HStack(spacing: 5) {
                ColorFormatInput(format: colorModel, color: $selection, label: "\(colorModel.rawValue) value")
                ColorCopyButton(value: colorModel.string(for: selection), title: "Copy \(colorModel.rawValue)", compact: true)
                    .buttonStyle(.borderless)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.panel, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1))
    }

    @ViewBuilder private var sliders: some View {
        if colorModel == .rgb {
            channelSlider("Red", value: selection.red * 255, maxValue: 255, suffix: "") {
                selection = StudioColor(red: $0 / 255, green: selection.green, blue: selection.blue, alpha: selection.alpha)
            }
            channelSlider("Green", value: selection.green * 255, maxValue: 255, suffix: "") {
                selection = StudioColor(red: selection.red, green: $0 / 255, blue: selection.blue, alpha: selection.alpha)
            }
            channelSlider("Blue", value: selection.blue * 255, maxValue: 255, suffix: "") {
                selection = StudioColor(red: selection.red, green: selection.green, blue: $0 / 255, alpha: selection.alpha)
            }
        } else {
            channelSlider("Hue", value: hue, maxValue: 359, suffix: "°", update: setHue)
            if colorModel == .hsl {
                channelSlider("Saturation", value: rememberedHSLSaturation * 100, maxValue: 100, suffix: "%") {
                    rememberedHSLSaturation = $0 / 100
                    selection = StudioColor(hue: hue, saturation: rememberedHSLSaturation, lightness: selection.hsl.lightness, alpha: selection.alpha)
                }
                channelSlider("Lightness", value: selection.hsl.lightness * 100, maxValue: 100, suffix: "%") {
                    selection = StudioColor(hue: hue, saturation: rememberedHSLSaturation, lightness: $0 / 100, alpha: selection.alpha)
                }
            } else {
                channelSlider("Saturation", value: rememberedSaturation * 100, maxValue: 100, suffix: "%") {
                    rememberedSaturation = $0 / 100
                    selection = StudioColor(hue: hue, saturation: rememberedSaturation, value: selection.hsv.value, alpha: selection.alpha)
                }
                channelSlider("Value", value: selection.hsv.value * 100, maxValue: 100, suffix: "%") {
                    selection = StudioColor(hue: hue, saturation: rememberedSaturation, value: $0 / 100, alpha: selection.alpha)
                }
            }
        }
    }

    private func channelSlider(_ label: String, value: Double, maxValue: Double, suffix: String,
                               update: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 7) {
            Text(label).font(.caption)
                .frame(width: 63, alignment: .leading)
            Slider(value: Binding(get: { min(value, maxValue) }, set: update), in: 0...maxValue, step: 1) {
                Text(label)
            }
            .labelsHidden()
            Text("\(Int(value.rounded()))" + suffix)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 33, alignment: .trailing)
        }
    }

    private func swatchGroup(_ title: String, colors: [StudioColor], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            StudioSectionTitle(title: title)
            if colors.isEmpty {
                Text(empty).font(.callout).foregroundStyle(.secondary)
            } else {
                ColorSwatchLine(colors: colors, action: { selection = $0 }, showLabels: false)
            }
        }
    }

    private func setHue(_ value: Double) {
        hue = min(max(0, value), 359.9999)
        if colorModel == .hsl {
            selection = StudioColor(hue: hue, saturation: rememberedHSLSaturation, lightness: selection.hsl.lightness, alpha: selection.alpha)
        } else {
            selection = StudioColor(hue: hue, saturation: rememberedSaturation, value: selection.hsv.value, alpha: selection.alpha)
        }
    }

    private func toggleFavorite() {
        if isFavorite {
            storedFavorites = encode(favorites.filter { $0.displayHex != selection.displayHex })
        } else {
            storedFavorites = encode([selection] + favorites)
        }
    }

    private func decode(_ data: Data) -> [StudioColor] { (try? JSONDecoder().decode([StudioColor].self, from: data)) ?? [] }
    private func encode(_ colors: [StudioColor]) -> Data { (try? JSONEncoder().encode(colors)) ?? Data() }
}
