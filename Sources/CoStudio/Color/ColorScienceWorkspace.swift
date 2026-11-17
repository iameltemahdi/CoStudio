import SwiftUI

struct ColorScienceWorkspace: View {
    @Binding var selection: StudioColor
    @State private var format: StudioColorFormat = .hex
    @State private var code: StudioCodeFormat = .css
    @State private var variation: ColorVariation = .tints
    @State private var harmony: ColorHarmony = .complementary

    var body: some View {
        ColorStudioPage(title: "Color Science", subtitle: "Convert color spaces, compare variations, and copy code.", section: "ANALYZE") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    conversions.frame(minWidth: 306, maxWidth: .infinity)
                    analysis.frame(minWidth: 240, maxWidth: 380)
                }
                VStack(alignment: .leading, spacing: 20) { conversions; analysis }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StudioSectionTitle(title: "Variations")
                    Spacer()
                    Picker("Variation type", selection: $variation) {
                        ForEach(ColorVariation.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
                ColorSwatchLine(colors: variation.colors(from: selection)) { selection = $0 }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StudioSectionTitle(title: "Color combinations")
                    Spacer()
                    Picker("Harmony", selection: $harmony) {
                        ForEach(ColorHarmony.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
                ColorSwatchLine(colors: harmony.colors(from: selection)) { selection = $0 }
            }
        }
    }

    private var conversions: some View {
        VStack(alignment: .leading, spacing: 13) {
            StudioSectionTitle(title: "Convert a color")
            HStack(spacing: 9) {
                ColorFilm(color: selection, cornerRadius: 6).frame(width: 33, height: 34)
                Picker("Input color space", selection: $format) {
                    ForEach(StudioColorFormat.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().fixedSize()
                Spacer()
            }
            ColorFormatInput(format: format, color: $selection, label: "\(format.rawValue) input", showApply: true)
            Text(format.inputHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()

            ForEach(StudioColorFormat.allCases) { item in
                HStack(spacing: 5) {
                    Text(item.rawValue)
                        .font(.caption.weight(.medium))
                        .frame(width: 46, alignment: .leading)
                    Text(item.string(for: selection))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ColorCopyButton(value: item.string(for: selection), title: "Copy \(item.rawValue)", compact: true)
                        .buttonStyle(.borderless)
                }
            }
            Text("Colors outside sRGB are clipped. CMYK values are approximate and depend on the print profile.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.panel, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1))
    }

    private var analysis: some View {
        VStack(alignment: .leading, spacing: 15) {
            StudioSectionTitle(title: "Color analysis")
            ColorFilm(color: selection).frame(height: 63)
            channel("Red", value: selection.red, color: Color(red: 0.76, green: 0.23, blue: 0.22))
            channel("Green", value: selection.green, color: Color(red: 0.20, green: 0.53, blue: 0.29))
            channel("Blue", value: selection.blue, color: Color(red: 0.23, green: 0.39, blue: 0.75))
            Divider()
            metric("HSL hue", "\(StudioColorFormat.decimal(selection.hsl.hue))°")
            metric("HSL saturation", percent(selection.hsl.saturation))
            metric("HSL lightness", percent(selection.hsl.lightness))
            metric("Perceptual lightness", percent(selection.oklab.lightness))
            metric("Relative luminance", StudioColorFormat.decimal(selection.relativeLuminance, precision: 4))
            metric("Hue temperature", selection.hueTemperature)

            Divider()
            StudioSectionTitle(title: "Code snippet")
            Picker("Code format", selection: $code) {
                ForEach(StudioCodeFormat.allCases) { Text($0.rawValue).tag($0) }
            }.labelsHidden()
            ScrollView(.horizontal) {
                Text(code.string(for: selection))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(10)
                    .frame(minHeight: 60, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioTheme.canvas, in: .rect(cornerRadius: 6))
            ColorCopyButton(value: code.string(for: selection), title: "Copy snippet").buttonStyle(.bordered)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.panel, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1))
    }

    private func channel(_ name: String, value: Double, color: Color) -> some View {
        HStack(spacing: 9) {
            Text(name)
                .font(.caption)
                .frame(width: 38, alignment: .leading)
            ProgressView(value: value).tint(color)
                .accessibilityLabel(name)
                .accessibilityValue(percent(value))
            Text("\(Int((value * 255).rounded()))")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 25, alignment: .trailing)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func percent(_ value: Double) -> String { StudioColorFormat.decimal(value * 100, precision: 1) + "%" }
}
