import SwiftUI

struct VisionSimulationWorkspace: View {
    @Binding var selection: StudioColor
    @State private var mode: ColorVisionMode = .deuteranopia
    @State private var source: Sample = .design
    @State private var custom = "#D45146, #4E9666, #3467A1, #DBAC50"
    @State private var customColors: [StudioColor] = [
        StudioColor(red: 0.831, green: 0.318, blue: 0.275), StudioColor(red: 0.306, green: 0.588, blue: 0.4),
        StudioColor(red: 0.204, green: 0.404, blue: 0.631), StudioColor(red: 0.859, green: 0.675, blue: 0.314)
    ]
    @State private var rejected = false

    enum Sample: String, CaseIterable, Identifiable {
        case design = "Example", current = "Current color", custom = "Custom colors"
        var id: Self { self }
    }

    private var colors: [StudioColor] {
        switch source {
        case .design:
            return [StudioColor(red: 0.87, green: 0.24, blue: 0.27), StudioColor(red: 0.15, green: 0.57, blue: 0.37),
                    StudioColor(red: 0.21, green: 0.39, blue: 0.77), StudioColor(red: 0.98, green: 0.76, blue: 0.20),
                    StudioColor(red: 0.64, green: 0.32, blue: 0.68), StudioColor(red: 0.09, green: 0.62, blue: 0.66)]
        case .current: return [selection]
        case .custom: return customColors
        }
    }

    var body: some View {
        ColorStudioPage(title: "Color Vision", subtitle: "Compare a palette before and after a color vision simulation.", section: "CHECK") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 17) { sourcePicker; modePicker }
                VStack(alignment: .leading, spacing: 12) { sourcePicker; modePicker }
            }
            if source == .current { StudioColorInput(label: "Current color", color: $selection) }
            if source == .custom { customInput }
            Text(mode.description)
                .font(.callout)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    preview("Original", colors: colors).frame(minWidth: 255, maxWidth: .infinity)
                    preview(mode.rawValue, colors: colors.map(mode.simulate)).frame(minWidth: 255, maxWidth: .infinity)
                }
                VStack(spacing: 16) {
                    preview("Original", colors: colors)
                    preview(mode.rawValue, colors: colors.map(mode.simulate))
                }
            }
            Text("Simulations approximate familiar forms of color vision deficiency. Use the contrast checker to verify text readability.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modePicker: some View {
        Picker("Simulation", selection: $mode) {
            ForEach(ColorVisionMode.allCases) { Text($0.rawValue).tag($0) }
        }.fixedSize()
    }

    private var sourcePicker: some View {
        Picker("Swatches", selection: $source) {
            ForEach(Sample.allCases) { Text($0.rawValue).tag($0) }
        }.fixedSize()
    }

    private var customInput: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                TextField("HEX colors separated by spaces", text: $custom)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit(apply)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif
                Button("Apply", action: apply).buttonStyle(.bordered)
            }
            if rejected {
                Text("Enter 1–16 HEX colors separated by commas or spaces.")
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func preview(_ title: String, colors: [StudioColor]) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            StudioSectionTitle(title: title)
            HStack(spacing: 0) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    ZStack {
                        if color.alpha < 1 { ColorCheckerboard() }
                        color.swiftUIColor
                    }
                    .accessibilityHidden(true)
                }
            }
            .frame(height: colors.count == 1 ? 188 : 122)
            .clipShape(.rect(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.black.opacity(0.12), lineWidth: 1))
            ColorSwatchLine(colors: colors, action: { StudioClipboard.copy($0.displayHex) }, actionTitle: "Copy")
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.panel, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1))
    }

    private func apply() {
        let tokens = custom.split { $0.isWhitespace || $0 == "," }
        let parsed = tokens.compactMap { StudioColor(hex: String($0)) }
        guard (1...16).contains(tokens.count), parsed.count == tokens.count else {
            rejected = true
            return
        }
        customColors = parsed
        rejected = false
    }
}
