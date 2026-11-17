import SwiftUI

struct ColorLibraryWorkspace: View {
    @Binding var selection: StudioColor
    @State private var query = ""
    @State private var family: ColorFamily?
    @State private var selectedName: String?

    private let columns = [GridItem(.adaptive(minimum: 106), spacing: 12)]

    private var colors: [NamedColor] {
        let text = query.lowercased().filter { !$0.isWhitespace }
        return NamedColor.library.filter { swatch in
            (family == nil || swatch.family == family) &&
            (text.isEmpty || swatch.name.contains(text) || swatch.color.hex.lowercased().contains(text))
        }
    }

    private var detail: NamedColor? {
        if let selectedName,
           let named = NamedColor.library.first(where: { $0.name == selectedName && $0.color.hex == selection.hex }) {
            return named
        }
        return NamedColor.library.first { $0.color.hex == selection.hex } ?? NamedColor.nearest(to: selection, count: 1).first
    }

    var body: some View {
        let current = detail
        ColorStudioPage(title: "Browse Colors", subtitle: "Explore the 148 named sRGB colors in CSS.", section: "PICK COLORS") {
            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search name or HEX", text: $query)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        #endif
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(9)
                .background(StudioTheme.panel, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(StudioTheme.line, lineWidth: 1))

                Picker("Color family", selection: $family) {
                    Text("All families").tag(ColorFamily?.none)
                    ForEach(ColorFamily.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
                .labelsHidden()
                .fixedSize()
            }

            if let current {
                details(current)
            }
            if colors.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                StudioSectionTitle(title: "\(colors.count) \(colors.count == 1 ? "color" : "colors")")
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(colors) { swatch in
                        Button {
                            use(swatch)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                ColorFilm(color: swatch.color, cornerRadius: 6).frame(height: 44)
                                Text(swatch.name).font(.caption.weight(.medium))
                                    .lineLimit(1).minimumScaleFactor(0.75)
                                Text(swatch.color.hex).font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(StudioTheme.panel, in: .rect(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(current?.id == swatch.id ? StudioTheme.accent : StudioTheme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(swatch.name), \(swatch.color.hex)")
                        .contextMenu {
                            Button("Copy HEX") { StudioClipboard.copy(swatch.color.hex) }
                        }
                    }
                }
            }
        }
    }

    private func details(_ swatch: NamedColor) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                ColorFilm(color: swatch.color).frame(width: 62, height: 57)
                VStack(alignment: .leading, spacing: 3) {
                    Text(swatch.name).font(.title3.weight(.semibold))
                    Text("\(swatch.family.rawValue) · \(swatch.color.hex)")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    if selection.hex != swatch.color.hex {
                        Button("Use nearest named color") { use(swatch) }
                            .buttonStyle(.plain)
                            .foregroundStyle(StudioTheme.accent)
                            .font(.caption)
                    }
                }
                Spacer()
                ColorCopyButton(value: swatch.color.hex, title: "Copy HEX", compact: true).buttonStyle(.bordered)
            }
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { detailsValues(swatch) }
                VStack(alignment: .leading, spacing: 5) { detailsValues(swatch) }
            }
            StudioSectionTitle(title: "Related colors")
            let related = NamedColor.nearest(to: swatch.color, count: 6, excluding: swatch.id)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 7)], spacing: 8) {
                ForEach(related) { item in
                    Button {
                        use(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            ColorFilm(color: item.color, cornerRadius: 5).frame(height: 24)
                            Text(item.name).font(.caption2).foregroundStyle(.secondary)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.name)
                }
            }
        }
        .padding(14)
        .background(StudioTheme.panel, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1))
    }

    @ViewBuilder private func detailsValues(_ swatch: NamedColor) -> some View {
        ForEach([StudioColorFormat.rgb, .hsl, .oklch]) { format in
            Text(format.string(for: swatch.color)).font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func use(_ swatch: NamedColor) {
        selectedName = swatch.name
        selection = swatch.color
    }
}
