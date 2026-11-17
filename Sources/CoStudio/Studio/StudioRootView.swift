import SwiftUI

struct StudioRootView: View {
    @State private var selection: StudioDestination? = .overview
    @State private var activeColor = StudioColor(red: 0.588, green: 0.686, blue: 0.467)
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var compactColumn: NavigationSplitViewColumn = .detail
    @State private var showColorMenu = false
    @AppStorage("appearance") private var appearance: StudioAppearance = .system

    var body: some View {
        NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn) {
            sidebar
        } detail: {
            workspace(selection ?? .overview)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(StudioTheme.canvas)
                .navigationTitle((selection ?? .overview).title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { colorControl }
                    #if os(iOS)
                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            StudioAppearancePicker(selection: $appearance)
                        } label: {
                            Label("Studio settings", systemImage: "gearshape")
                        }
                    }
                    #endif
                }
        }
        .navigationSplitViewStyle(.balanced)
        .focusedSceneValue(\.studioCommands, StudioCommandActions(navigate: navigate, copyColor: copyColor))
        #if os(macOS)
        .frame(minWidth: 690, minHeight: 530)
        #endif
    }

    private var sidebar: some View {
        List(selection: $selection) {
            sidebarLink(.overview)
            ForEach(StudioSection.allCases) { section in
                Section {
                    ForEach(section.destinations) { sidebarLink($0) }
                } header: {
                    Text(section.rawValue.uppercased())
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                        .tracking(1.25)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                StudioMark(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CoStudio").font(.headline.weight(.semibold))
                    Text("COLOR WORKSPACE")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .tracking(1.05)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 17)
            .padding(.top, 10)
            .padding(.bottom, 9)
            .accessibilityHidden(true)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(StudioTheme.accent).frame(width: 6, height: 6)
                Text("Local workspace").font(.caption)
                Spacer()
                Image(systemName: "internaldrive").font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(alignment: .top) {
                Rectangle().fill(StudioTheme.line).frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationSplitViewColumnWidth(min: 196, ideal: 218, max: 276)
    }

    private func sidebarLink(_ destination: StudioDestination) -> some View {
        NavigationLink(value: destination) {
            Label(destination.title, systemImage: destination.symbol)
                .font(.system(.subheadline))
                .labelStyle(.titleAndIcon)
        }
        .accessibilityIdentifier("nav-\(destination.rawValue)")
    }

    private var colorControl: some View {
        Button {
            showColorMenu.toggle()
        } label: {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(activeColor.swiftUIColor)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.17), lineWidth: 1))
                    .frame(width: 15, height: 15)
                Text(activeColor.hex)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .lineLimit(1)
            }
        }
        .accessibilityLabel("Active color \(activeColor.hex)")
        .accessibilityIdentifier("active-color")
        .popover(isPresented: $showColorMenu, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("ACTIVE COLOR")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Button("Copy \(activeColor.hex)", systemImage: "doc.on.doc") {
                    copyColor()
                    showColorMenu = false
                }
                Button("Open Color Picker", systemImage: "eyedropper") {
                    showColorMenu = false
                    navigate(.picker)
                }
            }
            .padding(17)
            .presentationCompactAdaptation(.popover)
        }
    }

    @ViewBuilder
    private func workspace(_ destination: StudioDestination) -> some View {
        switch destination {
        case .overview:
            StudioOverview(activeColor: $activeColor, navigate: navigate)
        case .picker:
            ColorPickerWorkspace(selection: $activeColor)
        case .image:
            ImageWorkspace(onSample: { activeColor = $0 })
        case .browse:
            ColorLibraryWorkspace(selection: $activeColor)
        case .palette:
            PaletteStudioView(seed: activeColor)
        case .gradient:
            GradientStudioView()
        case .library:
            StudioLibraryView()
        case .contrast:
            ContrastWorkspace(selection: $activeColor)
        case .vision:
            VisionSimulationWorkspace(selection: $activeColor)
        case .science:
            ColorScienceWorkspace(selection: $activeColor)
        }
    }

    private func navigate(_ destination: StudioDestination) {
        selection = destination
        compactColumn = .detail
    }

    private func copyColor() {
        StudioClipboard.copy(activeColor.displayHex)
    }
}
