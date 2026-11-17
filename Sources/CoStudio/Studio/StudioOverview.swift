import SwiftUI

struct StudioOverview: View {
    @Binding var activeColor: StudioColor
    let navigate: (StudioDestination) -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 38.0

    private let field = [
        ("Lichen", 0xD9F177 as UInt32, 1.38),
        ("Sage", 0x96AF77, 1.17),
        ("Mist", 0x83A594, 0.94),
        ("Clay", 0xD99878, 0.87),
        ("Parchment", 0xEAE0C3, 0.74),
        ("Ink", 0x262D21, 0.64)
    ]

    var body: some View {
        GeometryReader { geometry in
            let gutter: CGFloat = geometry.size.width > 940 ? 42 : StudioTheme.padding
            let wide = geometry.size.width >= 650
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    hero(wide: wide)
                    tools(wide: wide)
                }
                .frame(maxWidth: 1100)
                .padding(.horizontal, gutter)
                .padding(.top, 31)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("workspace-overview")
        }
    }

    private func hero(wide: Bool) -> some View {
        let layout = wide
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
        return layout {
            introduction
                .frame(maxWidth: wide ? 360 : .infinity, alignment: .leading)
            swatchStudy
                .frame(maxWidth: .infinity)
        }
        .padding(wide ? 28 : 23)
        .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(StudioTheme.line, lineWidth: 1).allowsHitTesting(false))
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 7) {
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 12, weight: .medium))
                Text("THE COLOR WORKSPACE")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .tracking(1.25)
            }
            .foregroundStyle(StudioTheme.accent)

            Text("Creative color tools.\nNo limits.")
                .font(.system(size: headlineSize, weight: .semibold))
                .tracking(-1.25)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("overview-headline")
                .accessibilityAddTraits(.isHeader)

            Text("Capture a color, build a palette, and take it from inspiration to production.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    pickerButton
                    paletteButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    pickerButton
                    paletteButton
                }
            }
            .padding(.top, 5)
        }
    }

    private var pickerButton: some View {
        Button {
            navigate(.picker)
        } label: {
            Label("Open Picker", systemImage: "eyedropper")
                .lineLimit(1)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier("open-picker")
    }

    private var paletteButton: some View {
        Button("New Palette") { navigate(.palette) }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("new-palette")
    }

    private var swatchStudy: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Text("FIELD STUDY")
                Spacer(minLength: 5)
                Text("01 / 06")
            }
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .tracking(1.15)
            .foregroundStyle(.secondary)
            GeometryReader { geometry in
                let totalWeight = field.reduce(0.0) { $0 + $1.2 }
                HStack(spacing: 0) {
                    ForEach(field, id: \.0) { item in
                        let hex = String(format: "#%06X", item.1)
                        Button {
                            if let color = StudioColor(hex: hex) { activeColor = color }
                        } label: {
                            Rectangle()
                                .fill(StudioTheme.rgb(item.1))
                                .overlay(alignment: .bottomLeading) {
                                    if activeColor.hex == hex {
                                        Circle()
                                            .fill(item.1 == 0x262D21 ? Color.white : StudioTheme.ink)
                                            .frame(width: 7, height: 7)
                                            .padding(10)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .frame(width: geometry.size.width * item.2 / totalWeight)
                        .accessibilityLabel("\(item.0), \(hex)")
                        .accessibilityHint("Sets the active color")
                        .accessibilityIdentifier("field-\(item.0.lowercased())")
                        .help("\(item.0) · \(hex)")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .frame(height: 137)
            HStack(spacing: 5) {
                Image(systemName: "cursorarrow.click").font(.system(size: 9))
                Text("Select a swatch to use it in the studio.")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(StudioTheme.canvas, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1).allowsHitTesting(false))
    }

    private func tools(wide: Bool) -> some View {
        let layout = wide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 17))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 17))
        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text("Studio tools")
                    .font(.system(.title3).weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("01 — 09")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            layout {
                ForEach(StudioSection.allCases) { section in
                    toolGroup(section)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func toolGroup(_ section: StudioSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.rawValue.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .tracking(0.9)
                .foregroundStyle(StudioTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .accessibilityAddTraits(.isHeader)

            ForEach(section.destinations) { destination in
                Rectangle().fill(StudioTheme.line).frame(height: 1)
                Button {
                    navigate(destination)
                } label: {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: destination.symbol)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(StudioTheme.accent)
                            .frame(width: 17, height: 16)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(destination.title)
                                .font(.system(.subheadline).weight(.medium))
                            Text(destination.caption)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 3)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 39, alignment: .leading)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("overview-\(destination.rawValue)")
            }
        }
        .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1).allowsHitTesting(false))
    }
}
