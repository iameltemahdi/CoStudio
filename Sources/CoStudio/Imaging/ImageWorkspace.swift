import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImageWorkspace: View {
    let onSample: (StudioColor) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudioPalette.name) private var palettes: [StudioPalette]
    @State private var model = ImageWorkspaceModel()
    @State private var mode: ImageWorkspaceTool = .sample
    @State private var zoom = 1.0
    @State private var compare = false
    @State private var crop = ImageCrop.whole
    @State private var importing = false
    @State private var exporting = false
    @State private var exportedArtwork: ExportedArtwork?
    @State private var exportFormat: StudioImageFormat = .png
    @State private var removal: ImportedArtwork?
    @State private var targeted = false

    init(onSample: @escaping (StudioColor) -> Void = { _ in }) {
        self.onSample = onSample
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    WorkspaceHeader(
                        title: "Image Studio",
                        subtitle: "Sample colors, extract palettes and edit images on this device.",
                        eyebrow: "PICK COLORS"
                    )
                    commandBar
                    if let image = displayedImage {
                        if geometry.size.width >= 756 {
                            HStack(alignment: .top, spacing: 17) {
                                stage(image, height: stageHeight(geometry.size.height))
                                inspector.frame(width: 244)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                stage(image, height: stageHeight(geometry.size.height))
                                inspector
                            }
                        }
                    } else {
                        emptyStage
                    }
                    if let status = model.status {
                        Label(status, systemImage: "checkmark.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(StudioTheme.padding)
                .frame(maxWidth: 1500)
                .frame(maxWidth: .infinity)
            }
        }
        .background(StudioTheme.canvas)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let file): openFile(file)
            case .failure(let error): model.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportedArtwork,
            contentType: exportFormat.contentType,
            defaultFilename: (model.current?.name ?? "CoStudio") + " Edited"
        ) { result in
            switch result {
            case .success: model.status = "Edited copy exported."
            case .failure(let error): model.errorMessage = error.localizedDescription
            }
        }
        .alert("Image Studio", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog("Remove local image?", isPresented: Binding(
            get: { removal != nil },
            set: { if !$0 { removal = nil } }
        ), presenting: removal) { item in
            Button("Remove \(item.name)", role: .destructive) { model.remove(item) }
        } message: { _ in
            Text("This removes the studio copy and its edits.")
        }
        .task {
            model.restoreCatalog()
            if model.current == nil, let latest = model.artwork.first { await openArtwork(latest) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .coStudioImageLibraryDidRestore)) { _ in
            model.restoreCatalog()
        }
        .onChange(of: mode) { _, _ in
            compare = false
            crop = .whole
            model.discardPreview()
        }
        .onChange(of: compare) { _, _ in model.clearSelection() }
        .onChange(of: model.previewEdit) { previous, next in
            if previous != nil && next == nil { compare = false }
        }
    }

    private var displayedImage: CGImage? {
        if compare { return model.preview == nil ? model.original : model.image }
        return model.preview ?? model.image
    }

    private var commandBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button("Import", systemImage: "plus") { importing = true }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(model.busy)
                    .accessibilityIdentifier("image-import")
                libraryMenu
                Spacer(minLength: 0)
                if model.busy {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel("Processing image")
                }
                if model.image != nil {
                    exportMenu
                }
            }
            if model.image != nil {
                ScrollView(.horizontal) {
                    HStack(spacing: 13) {
                        editButtons
                        Divider().frame(height: 17)
                        Menu {
                            Button("Fit") { zoom = 1 }
                            Button("150% of fit") { zoom = 1.5 }
                            Button("200% of fit") { zoom = 2 }
                            Button("300% of fit") { zoom = 3 }
                            Button("400% of fit") { zoom = 4 }
                        } label: {
                            Label(zoom == 1 ? "Fit" : "\(Int(zoom * 100))%", systemImage: "magnifyingglass")
                        }
                        .fixedSize()
                        Button(comparisonTitle, systemImage: "rectangle.split.2x1") {
                            compare.toggle()
                        }
                        .fixedSize()
                        .help(model.preview == nil ? "Compare with the original file" : "Compare before and after this edit")
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.busy)
                    .padding(.vertical, 3)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var editButtons: some View {
        HStack(spacing: 10) {
            Button {
                compare = false
                Task { await model.undo() }
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(model.history.applied.isEmpty)
            .accessibilityLabel("Undo image edit")
            .help("Undo image edit")

            Button {
                compare = false
                Task { await model.redo() }
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(model.history.undone.isEmpty)
            .accessibilityLabel("Redo image edit")
            .help("Redo image edit")

            Button {
                compare = false
                Task { await model.apply(.rotateClockwise) }
            } label: {
                Image(systemName: "rotate.right")
            }
            .accessibilityLabel("Rotate clockwise")
            .help("Rotate clockwise")

            Button {
                compare = false
                crop = .whole
                zoom = 1
                Task { await model.reset() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(model.history.applied.isEmpty)
            .accessibilityLabel("Reset to original")
            .help("Reset to original")
        }
        .disabled(model.preview != nil)
        .font(.body.weight(.medium))
        .padding(.horizontal, 2)
    }

    private var libraryMenu: some View {
        Menu {
            if model.artwork.isEmpty {
                Text("No imported images")
            } else {
                Section("Local originals") {
                    ForEach(model.artwork) { item in
                        Button {
                            Task { await openArtwork(item) }
                        } label: {
                            if item.id == model.current?.id {
                                Label(item.name, systemImage: "checkmark")
                            } else {
                                Text(item.name)
                            }
                        }
                    }
                }
                if let item = model.current {
                    Button("Remove Current Image…", role: .destructive) { removal = item }
                }
            }
        } label: {
            Label("Library", systemImage: "folder")
        }
        .disabled(model.busy)
    }

    private var exportMenu: some View {
        Menu {
            ForEach(StudioImageFormat.allCases) { format in
                Button(format.rawValue) {
                    Task {
                        exportFormat = format
                        exportedArtwork = await model.export(format)
                        exporting = exportedArtwork != nil
                    }
                }
            }
        } label: {
            Label("Export Copy", systemImage: "square.and.arrow.up")
        }
        .disabled(model.busy || model.preview != nil)
        .accessibilityIdentifier("image-export")
    }

    private var emptyStage: some View {
        VStack(spacing: 13) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 31, weight: .light))
                .foregroundStyle(StudioTheme.accent)
                .accessibilityHidden(true)
            Text("Open an image")
                .font(.title3.weight(.semibold))
            Text("Drop a local file here, or choose one to import.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { emptyStageButtons }
                VStack(spacing: 8) { emptyStageButtons }
            }
            .disabled(model.busy)
        }
        .padding(25)
        .frame(maxWidth: .infinity, minHeight: 315)
        .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    targeted ? StudioTheme.accent : StudioTheme.line,
                    style: StrokeStyle(lineWidth: targeted ? 2 : 1, dash: [5, 4])
                )
        }
        .dropDestination(for: URL.self) { items, _ in
            guard let item = items.first, item.isFileURL, !model.busy else { return false }
            openFile(item)
            return true
        } isTargeted: { targeted = $0 }
    }

    @ViewBuilder
    private var emptyStageButtons: some View {
        Button("Choose Image…") { importing = true }
            .buttonStyle(.borderedProminent)
        if let sample = Bundle.main.url(forResource: "StudioSample", withExtension: "png") {
            Button("Open Sample Image") { openFile(sample) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("image-sample")
        }
    }

    private func stage(_ image: CGImage, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.current?.name ?? "Image")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(compactStageStatus(image))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Rectangle().fill(StudioTheme.line).frame(height: 1)
            ImageStudioCanvas(
                image: image,
                tool: mode,
                zoom: $zoom,
                crop: $crop,
                selectable: !compare && model.preview == nil && !model.busy,
                selected: compare ? nil : model.pickedPosition,
                onSelect: { model.select(at: $0, from: image) }
            )
            .frame(height: height)
            .accessibilityIdentifier("image-stage")
        }
        .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 9))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(targeted ? StudioTheme.accent : StudioTheme.line, lineWidth: targeted ? 2 : 1)
        }
        .dropDestination(for: URL.self) { items, _ in
            guard let item = items.first, item.isFileURL, !model.busy else { return false }
            openFile(item)
            return true
        } isTargeted: { targeted = $0 }
    }

    private var inspector: some View {
        ImageInspector(
            model: model, tool: $mode, crop: $crop, palettes: palettes, comparing: compare,
            useColor: { color in
                onSample(color)
                model.status = "Studio color set to \(color.displayHex)."
            },
            savePalette: savePalette
        )
    }

    private func compactStageStatus(_ image: CGImage) -> String {
        let state = compare ? (model.preview == nil ? "ORIGINAL" : "BEFORE") : model.preview == nil ? "" : "PREVIEW"
        let dimensions = "\(image.width) × \(image.height) PX"
        return state.isEmpty ? dimensions : state + "  ·  " + dimensions
    }

    private var comparisonTitle: String {
        if compare { return model.preview == nil ? "Show edit" : "Show preview" }
        return model.preview == nil ? "Original" : "Before"
    }

    private func stageHeight(_ available: CGFloat) -> CGFloat { min(660, max(250, available - 241)) }

    private func openFile(_ file: URL) {
        guard file.isFileURL else { return }
        Task {
            resetViewControls()
            await model.importImage(file)
        }
    }

    private func openArtwork(_ artwork: ImportedArtwork) async {
        resetViewControls()
        await model.open(artwork)
    }

    private func resetViewControls() {
        compare = false
        mode = .sample
        zoom = 1
        crop = .whole
    }

    private func savePalette(_ colors: [StudioColor]) {
        let base = model.current?.name ?? "Image"
        let suffix = colors.count == 1 ? " Color" : " Palette"
        let palette = StudioPalette(name: base + suffix, hexColors: colors.map(\.displayHex))
        modelContext.insert(palette)
        do {
            try modelContext.save()
            model.status = "Saved \(palette.name) to the palette library."
        } catch {
            modelContext.delete(palette)
            model.errorMessage = error.localizedDescription
        }
    }
}

enum ImageWorkspaceTool: String, CaseIterable, Identifiable {
    case sample = "Sample colors"
    case crop = "Crop"
    case replace = "Replace a color"
    case palette = "Apply a palette"
    case background = "Remove background"

    var id: Self { self }

    var icon: String {
        switch self {
        case .sample: "eyedropper"
        case .crop: "crop"
        case .replace: "wand.and.rays"
        case .palette: "swatchpalette"
        case .background: "person.crop.rectangle"
        }
    }
}
