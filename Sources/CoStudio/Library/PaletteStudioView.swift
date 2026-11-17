import SwiftUI
import SwiftData

struct PaletteStudioView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StudioPalette.order) private var palettes: [StudioPalette]
    @State private var paletteID: UUID?
    private let collectionID: UUID?
    @State private var name: String
    @State private var swatches: [PaletteSwatch]
    @State private var selection: UUID?
    @State private var harmony = PaletteHarmony.analogous
    @State private var export = CreativeExportDocument()
    @State private var exportFormat = PaletteExport.hex
    @State private var exporting = false
    @State private var errorMessage: String?
    @State private var notice: String?

    init(seed: StudioColor? = nil, palette: StudioPalette? = nil, collectionID: UUID? = nil) {
        self.collectionID = collectionID
        let colors = palette?.hexColors ?? ["#253326", "#52694C", "#879879", "#C1CBA7", "#EEF0DB"]
        var loaded = colors.compactMap(StudioColor.init(hex:))
        if palette == nil, let seed, loaded.indices.contains(1) {
            loaded[1] = seed
            var generator = SystemRandomNumberGenerator()
            loaded = PaletteHarmony.monochromatic.generate(colors: loaded, locked: [1], using: &generator)
        }
        let initialSwatches = loaded.map(PaletteSwatch.init)
        _paletteID = State(initialValue: palette?.id)
        _name = State(initialValue: palette?.name ?? "Untitled Palette")
        _swatches = State(initialValue: initialSwatches)
        _selection = State(initialValue: initialSwatches.first?.id)
    }

    private var editedPalette: StudioPalette? { palettes.first { $0.id == paletteID } }
    private var colors: [StudioColor] { swatches.map(\.color) }
    private var savedValues: [String] { colors.map(\.exportHex) }
    private var selectedIndex: Int? { swatches.firstIndex { $0.id == selection } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                WorkspaceHeader(
                    title: "Palette Generator",
                    subtitle: "Generate harmonies, lock a swatch, or tune each color by hand.",
                    eyebrow: "Create"
                )
                paletteActions
                strip
                if let index = selectedIndex { inspector(index: index) }
                saveBar
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .padding(StudioTheme.padding)
            .frame(maxWidth: .infinity)
        }
        .fileExporter(
            isPresented: $exporting,
            document: export,
            contentType: exportFormat.contentType,
            defaultFilename: "\(normalizedName).\(exportFormat.fileExtension)"
        ) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .alert("Palette", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .onChange(of: savedValues) { _, _ in updateSavedPalette(colors: true) }
        .onChange(of: editedPalette?.hexColors) { previous, incoming in
            if let incoming, incoming != savedValues {
                let refreshed = incoming.compactMap(StudioColor.init(hex:)).map(PaletteSwatch.init)
                guard !refreshed.isEmpty else { return }
                let slot = selectedIndex ?? 0
                swatches = refreshed
                selection = refreshed[min(slot, refreshed.count - 1)].id
            } else if previous != nil, incoming == nil {
                paletteID = nil
                notice = "Palette deleted in another window. Save to keep a copy."
            }
        }
        .onChange(of: editedPalette?.name) { _, incoming in
            if let incoming { name = incoming }
        }
    }

    private var paletteActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                harmonyPicker
                Spacer(minLength: 10)
                generateButton
                addButton
            }
            VStack(alignment: .leading, spacing: 10) {
                harmonyPicker
                HStack {
                    generateButton
                    addButton
                }
            }
        }
    }

    private var harmonyPicker: some View {
        Picker("Harmony", selection: $harmony) {
            ForEach(PaletteHarmony.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.menu)
        .fixedSize()
    }

    private var generateButton: some View {
        Button("Generate", systemImage: "shuffle", action: generate)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("r")
            .disabled(!swatches.contains { !$0.isLocked })
    }

    private var addButton: some View {
        Button("Add swatch", systemImage: "plus") {
            let swatch = PaletteSwatch(colors.last ?? StudioColor(red: 0.5, green: 0.5, blue: 0.5))
            swatches.append(swatch)
            selection = swatch.id
        }
        .buttonStyle(.bordered)
    }

    private var strip: some View {
        GeometryReader { geometry in
            let width = max(96, geometry.size.width / CGFloat(max(swatches.count, 1)))
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(swatches) { swatch in
                        swatchTile(swatch)
                            .frame(width: width)
                    }
                }
                .frame(height: 260)
            }
            .scrollIndicators(.visible)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1).allowsHitTesting(false) }
        }
        .frame(height: 260)
    }

    private func swatchTile(_ swatch: PaletteSwatch) -> some View {
        VStack(spacing: 0) {
            Button {
                selection = swatch.id
            } label: {
                ColorCheckerboard(tile: 9)
                    .overlay { swatch.color.swiftUIColor }
                    .overlay(alignment: .bottomLeading) {
                        if selection == swatch.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(StudioTheme.ink)
                                .frame(width: 26, height: 26)
                                .background(.white, in: Circle())
                                .padding(10)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(swatch.color.exportHex)")
            .accessibilityAddTraits(selection == swatch.id ? .isSelected : [])

            HStack(spacing: 4) {
                Text(swatch.color.exportHex)
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button {
                    guard let index = swatches.firstIndex(where: { $0.id == swatch.id }) else { return }
                    swatches[index].isLocked.toggle()
                } label: {
                    Image(systemName: swatch.isLocked ? "lock.fill" : "lock.open")
                }
                .buttonStyle(.borderless)
                .help(swatch.isLocked ? "Unlock swatch" : "Lock swatch")
                .accessibilityLabel(swatch.isLocked ? "Unlock \(swatch.color.exportHex)" : "Lock \(swatch.color.exportHex)")
            }
            .padding(.horizontal, 8)
            .frame(height: 42)
            .background(selection == swatch.id ? StudioTheme.line : StudioTheme.panel)
        }
        .overlay(alignment: .trailing) { Rectangle().fill(StudioTheme.line).frame(width: 1).allowsHitTesting(false) }
    }

    private func inspector(index: Int) -> some View {
        let editing = $swatches[index].color
        let swatch = swatches[index]
        return CreativePanel {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    swatchEditor(index: index, color: editing, swatch: swatch)
                    Spacer(minLength: 10)
                    swatchActions(index: index, swatch: swatch)
                }
                VStack(alignment: .leading, spacing: 12) {
                    swatchEditor(index: index, color: editing, swatch: swatch)
                    swatchActions(index: index, swatch: swatch)
                }
            }
        }
    }

    private func swatchEditor(index: Int, color: Binding<StudioColor>, swatch: PaletteSwatch) -> some View {
        HStack(spacing: 12) {
            CreativeColorControl(title: "Swatch color", value: color)
            VStack(alignment: .leading, spacing: 3) {
                Text("Swatch \(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                CreativeHexField(value: color)
                    .id(swatch.id)
                    .frame(width: 104, alignment: .leading)
            }
        }
    }

    private func swatchActions(index: Int, swatch: PaletteSwatch) -> some View {
        HStack(spacing: 9) {
            Button {
                StudioClipboard.copy(swatch.color.exportHex)
                notice = "Swatch copied"
            } label: { Image(systemName: "doc.on.doc") }
                .help("Copy swatch")
                .accessibilityLabel("Copy swatch")
            Button {
                swatches.swapAt(index, index - 1)
            } label: { Image(systemName: "arrow.left") }
                .disabled(index == 0)
                .help("Move swatch left")
                .accessibilityLabel("Move swatch left")
            Button {
                swatches.swapAt(index, index + 1)
            } label: { Image(systemName: "arrow.right") }
                .disabled(index == swatches.count - 1)
                .help("Move swatch right")
                .accessibilityLabel("Move swatch right")
            Button(role: .destructive) {
                swatches.remove(at: index)
                selection = swatches[min(index, swatches.count - 1)].id
            } label: { Image(systemName: "minus") }
                .disabled(swatches.count <= 1)
                .help("Remove swatch")
                .accessibilityLabel("Remove swatch")
        }
        .buttonStyle(.bordered)
    }

    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack { nameField; Spacer(minLength: 12); saveActions }
                VStack(alignment: .leading, spacing: 10) { nameField; saveActions }
            }
            if let notice {
                Label(notice, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(StudioTheme.accent)
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Palette name").font(.caption).foregroundStyle(.secondary)
            TextField("Palette name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(idealWidth: 175, maxWidth: 275)
                .onSubmit { updateSavedPalette(name: true) }
        }
    }

    private var saveActions: some View {
        HStack(spacing: 10) {
            Button("Copy", systemImage: "doc.on.doc") {
                StudioClipboard.copy(savedValues.joined(separator: "\n"))
                notice = "Palette copied"
            }
            .buttonStyle(.bordered)
            Menu {
                ForEach(PaletteExport.allCases) { format in
                    Button(format.rawValue) { exportPalette(as: format) }
                }
            } label: { Label("Export", systemImage: "square.and.arrow.up") }
            Button(paletteID == nil ? "Save Palette" : "Save", systemImage: "tray.and.arrow.down", action: savePalette)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s")
        }
        .fixedSize()
    }

    private var normalizedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Palette" : trimmed
    }

    private func generate() {
        var generator = SystemRandomNumberGenerator()
        let locked = Set(swatches.indices.filter { swatches[$0].isLocked })
        let generated = harmony.generate(colors: colors, locked: locked, using: &generator)
        for index in swatches.indices { swatches[index].color = generated[index] }
    }

    private func savePalette() {
        if paletteID != nil {
            updateSavedPalette(name: true, colors: true)
            if errorMessage == nil { notice = "Palette saved" }
            return
        }
        let model = StudioPalette(
            name: normalizedName, hexColors: savedValues, collectionID: collectionID,
            order: nextLibraryOrder(palettes.map(\.order))
        )
        context.insert(model)
        do {
            try context.save()
            paletteID = model.id
            notice = "Saved to Projects & Collections"
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func updateSavedPalette(name: Bool = false, colors: Bool = false) {
        guard let palette = editedPalette else { return }
        let nameChanged = name && palette.name != normalizedName
        let colorsChanged = colors && palette.hexColors != savedValues
        guard nameChanged || colorsChanged else { return }
        if nameChanged { palette.name = normalizedName }
        if colorsChanged { palette.hexColors = savedValues }
        palette.updatedAt = .now
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func exportPalette(as format: PaletteExport) {
        do {
            export = CreativeExportDocument(data: try format.data(name: normalizedName, colors: colors))
            exportFormat = format
            exporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
