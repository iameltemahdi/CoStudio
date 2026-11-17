import SwiftData
import SwiftUI

struct StudioLibraryView: View {
    @Environment(\.modelContext) var context
    @Query(sort: [SortDescriptor(\StudioProject.order), SortDescriptor(\StudioProject.name)]) var projects: [StudioProject]
    @Query(sort: [SortDescriptor(\StudioCollection.order), SortDescriptor(\StudioCollection.name)]) var collections: [StudioCollection]
    @Query(sort: [SortDescriptor(\StudioPalette.order), SortDescriptor(\StudioPalette.name)]) var palettes: [StudioPalette]
    @State var scope = LibraryScope.root
    @State private var search = ""
    @State private var favoritesOnly = false
    @State var namePrompt: LibraryNamePrompt?
    @State private var paletteEdit: LibraryPaletteEdit?
    @State var pendingDelete: LibraryItem?
    @State var errorMessage: String?
    @State var notice: String?
    @State private var backup = LibraryBackupDocument()
    @State private var exporting = false
    @State private var importing = false
    @State private var restoring = false

    var body: some View {
        ScrollView {
            let projectResults = filteredProjects
            let collectionResults = filteredCollections
            let paletteResults = filteredPalettes
            VStack(alignment: .leading, spacing: 21) {
                WorkspaceHeader(
                    title: "Projects & Collections",
                    subtitle: "Organize your palettes and keep a restorable copy of your local library.",
                    eyebrow: "Library"
                )
                controls
                if scope != .root { breadcrumb }
                if projectResults.isEmpty && collectionResults.isEmpty && paletteResults.isEmpty {
                    emptyState
                } else {
                    itemList("Projects", items: projectResults)
                    itemList("Collections", items: collectionResults)
                    itemList("Palettes", items: paletteResults)
                }
                if let notice {
                    Label(notice, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.accent)
                }
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .padding(StudioTheme.padding)
            .frame(maxWidth: .infinity)
        }
        .disabled(restoring)
        .overlay {
            if restoring {
                CreativePanel {
                    ProgressView("Restoring library…")
                        .padding(.vertical, 9)
                        .padding(.horizontal, 20)
                }
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: backup,
            contentType: .studioLibraryBackup,
            defaultFilename: "CoStudio Library.costudiobackup"
        ) { result in
            switch result {
            case .success: notice = "Library backup exported"
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.studioLibraryBackup]) { result in
            do {
                let url = try result.get()
                restoreBackup(from: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $namePrompt) { prompt in
            LibraryNameSheet(prompt: prompt, onSave: apply)
        }
        .sheet(item: $paletteEdit) { editor in
            NavigationStack {
                PaletteStudioView(palette: editor.palette, collectionID: editor.collectionID)
                    .background(StudioTheme.canvas)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { paletteEdit = nil }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 720, minHeight: 550)
            #endif
        }
        .alert("Library", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .confirmationDialog("Delete \(pendingDelete?.name ?? "item")?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible, presenting: pendingDelete) { item in
            Button("Delete", role: .destructive) { delete(item) }
        } message: { item in Text(item.deletionNote) }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchField
                Spacer(minLength: 0)
                controlActions
            }
            VStack(alignment: .leading, spacing: 10) {
                searchField
                controlActions
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search names or HEX", text: $search)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search library")
            if !search.isEmpty {
                Button {
                    search = ""
                } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(minWidth: 150, idealWidth: 210, maxWidth: 300)
        .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 7))
        .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(StudioTheme.line, lineWidth: 1) }
    }

    private var controlActions: some View {
        HStack(spacing: 10) {
            Button {
                favoritesOnly.toggle()
            } label: { Image(systemName: favoritesOnly ? "star.fill" : "star") }
                .buttonStyle(.bordered)
                .accessibilityLabel(favoritesOnly ? "Show all items" : "Show favorites")
                .help(favoritesOnly ? "Show all items" : "Show favorites")
            Menu {
                Button("New Palette", systemImage: "swatchpalette") {
                    paletteEdit = LibraryPaletteEdit(collectionID: activePaletteCollection)
                }
                .disabled(requiresCollection)
                Button("New Project", systemImage: "folder") {
                    namePrompt = LibraryNamePrompt(action: .project, name: "")
                }
                Button("New Collection", systemImage: "square.stack") {
                    namePrompt = LibraryNamePrompt(action: .collection, name: "")
                }
            } label: { Label("New", systemImage: "plus") }
            Menu {
                Button("Export Library Backup", systemImage: "arrow.up.document", action: exportBackup)
                Button("Restore Library Backup", systemImage: "arrow.down.document") { importing = true }
            } label: { Label("Backup", systemImage: "externaldrive") }
        }
        .fixedSize()
    }

    private var activePaletteCollection: UUID? {
        switch scope {
        case .root: nil
        case .project(let id): collections.first { $0.projectID == id }?.id
        case .collection(let id): id
        }
    }

    private var requiresCollection: Bool {
        if case .project = scope { return activePaletteCollection == nil }
        return false
    }

    private var breadcrumb: some View {
        HStack(spacing: 7) {
            Button("All items") { scope = .root }
                .buttonStyle(.plain)
                .foregroundStyle(StudioTheme.accent)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            switch scope {
            case .root:
                EmptyView()
            case .project(let id):
                Text(projects.first { $0.id == id }?.name ?? "Project")
            case .collection(let id):
                if let collection = collections.first(where: { $0.id == id }) {
                    if let parent = projects.first(where: { $0.id == collection.projectID }) {
                        Button(parent.name) { scope = .project(parent.id) }
                            .buttonStyle(.plain)
                            .foregroundStyle(StudioTheme.accent)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    Text(collection.name)
                }
            }
            Spacer()
        }
        .font(.subheadline)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            search.isEmpty && !favoritesOnly ? "Nothing saved here" : "No matching items",
            systemImage: search.isEmpty ? "folder" : "magnifyingglass",
            description: Text(emptyDescription)
        )
        .frame(minHeight: 280)
        .frame(maxWidth: .infinity)
        .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1) }
    }

    private var emptyDescription: String {
        if !search.isEmpty || favoritesOnly { return "Change your search or clear the favorites filter." }
        if requiresCollection { return "Create a collection to organize palettes in this project." }
        return "Use New to add an item."
    }

    @ViewBuilder
    private func itemList(_ title: String, items: [LibraryItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                    Text("\(items.count)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(items.count) items")
                }
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        itemRow(item)
                        if item.id != items.last?.id { Divider().overlay(StudioTheme.line) }
                    }
                }
                .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 9))
                .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1).allowsHitTesting(false) }
            }
        }
    }

    private func itemRow(_ item: LibraryItem) -> some View {
        HStack(spacing: 10) {
            Button {
                switch item {
                case .project(let project): scope = .project(project.id)
                case .collection(let collection): scope = .collection(collection.id)
                case .palette(let palette): paletteEdit = LibraryPaletteEdit(palette: palette)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.symbol)
                        .frame(width: 20)
                        .foregroundStyle(StudioTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        Text(detail(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if case .palette(let palette) = item {
                        palettePreview(palette)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                item.favorite.toggle()
                saveChanges()
            } label: {
                Image(systemName: item.favorite ? "star.fill" : "star")
                    .foregroundStyle(item.favorite ? StudioTheme.accent : .secondary)
                    .frame(minWidth: 25, minHeight: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.favorite ? "Remove \(item.name) from favorites" : "Favorite \(item.name)")
            rowMenu(item)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
    }

    private func rowMenu(_ item: LibraryItem) -> some View {
        let location = movement(for: item)
        return Menu {
            Button("Rename", systemImage: "pencil") {
                namePrompt = LibraryNamePrompt(action: .rename(item), name: item.name)
            }
            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(item) }
            destinationMenu(item)
            Button("Move Up", systemImage: "arrow.up") { move(item, step: -1) }
                .disabled(location.index == 0)
            Button("Move Down", systemImage: "arrow.down") { move(item, step: 1) }
                .disabled(location.index >= location.siblings.count - 1)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = item }
        } label: { Image(systemName: "ellipsis") }
        #if os(macOS)
        .menuIndicator(.hidden)
        #endif
        .fixedSize()
        .accessibilityLabel("Options for \(item.name)")
    }

    @ViewBuilder
    private func destinationMenu(_ item: LibraryItem) -> some View {
        switch item {
        case .project:
            EmptyView()
        case .collection(let collection):
            Menu("Move to Project", systemImage: "folder") {
                Button("No Project") { assign(collection, to: nil) }.disabled(collection.projectID == nil)
                ForEach(projects) { project in
                    Button(project.name) { assign(collection, to: project.id) }
                        .disabled(collection.projectID == project.id)
                }
            }
        case .palette(let palette):
            Menu("Move to Collection", systemImage: "square.stack") {
                Button("No Collection") { assign(palette, to: nil) }.disabled(palette.collectionID == nil)
                ForEach(collections) { collection in
                    Button(collection.name) { assign(palette, to: collection.id) }
                        .disabled(palette.collectionID == collection.id)
                }
            }
        }
    }

    private func palettePreview(_ palette: StudioPalette) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(palette.hexColors.prefix(5).enumerated()), id: \.offset) { _, value in
                StudioColor(hex: value)?.swiftUIColor ?? StudioTheme.line
            }
        }
        .frame(width: 56, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(StudioTheme.line, lineWidth: 1) }
        .accessibilityHidden(true)
    }

    private var filteredProjects: [LibraryItem] {
        guard scope == .root else { return [] }
        return projects.map(LibraryItem.project).filter(matches)
    }

    private var filteredCollections: [LibraryItem] {
        collections.filter {
            switch scope {
            case .root: true
            case .project(let id): $0.projectID == id
            case .collection: false
            }
        }.map(LibraryItem.collection).filter(matches)
    }

    private var filteredPalettes: [LibraryItem] {
        let collectionIDs: Set<UUID>
        if case .project(let id) = scope {
            collectionIDs = Set(collections.filter { $0.projectID == id }.map(\.id))
        } else {
            collectionIDs = []
        }

        return palettes.filter {
            switch scope {
            case .root: true
            case .project: $0.collectionID.map(collectionIDs.contains) ?? false
            case .collection(let id): $0.collectionID == id
            }
        }.map(LibraryItem.palette).filter(matches)
    }

    private func matches(_ item: LibraryItem) -> Bool {
        if favoritesOnly && !item.favorite { return false }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty || item.name.localizedCaseInsensitiveContains(query) { return true }
        if case .palette(let palette) = item {
            return palette.hexColors.contains { $0.localizedCaseInsensitiveContains(query) }
        }
        return false
    }

    private func detail(for item: LibraryItem) -> String {
        switch item {
        case .project(let project):
            let count = collections.filter { $0.projectID == project.id }.count
            return "\(count) \(count == 1 ? "collection" : "collections")"
        case .collection(let collection):
            let count = palettes.filter { $0.collectionID == collection.id }.count
            return "\(count) \(count == 1 ? "palette" : "palettes")"
        case .palette(let palette):
            let count = palette.hexColors.count
            let summary = "\(count) \(count == 1 ? "swatch" : "swatches")"
            guard let collection = collections.first(where: { $0.id == palette.collectionID }) else { return summary }
            return "\(summary) · \(collection.name)"
        }
    }

    private func restoreBackup(from url: URL) {
        restoring = true
        Task { @MainActor in
            defer { restoring = false }
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try LibraryBackupDocument.readPackage(at: url)
                }.value
                try LibraryBackupDocument.restore(snapshot, into: context)
                notice = "Library backup restored"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func exportBackup() {
        do {
            let snapshot = LibrarySnapshot(projects: projects, collections: collections, palettes: palettes)
            let images = ImageLibrary.directory
            backup = LibraryBackupDocument(
                libraryData: try snapshot.encoded(),
                imagesDirectory: FileManager.default.fileExists(atPath: images.path) ? images : nil
            )
            exporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct LibraryNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    private let title: String
    private let action: LibraryNamePrompt.Action
    let onSave: (LibraryNamePrompt.Action, String) -> Void

    init(prompt: LibraryNamePrompt, onSave: @escaping (LibraryNamePrompt.Action, String) -> Void) {
        self._name = State(initialValue: prompt.name)
        self.title = prompt.title
        self.action = prompt.action
        self.onSave = onSave
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.weight(.semibold))
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(22)
        .frame(idealWidth: 340)
        .presentationDetents([.height(180)])
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        onSave(action, trimmed)
        dismiss()
    }
}
