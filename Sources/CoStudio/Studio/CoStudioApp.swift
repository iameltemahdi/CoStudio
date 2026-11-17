import SwiftUI
import SwiftData

@main
struct CoStudioApp: App {
    @AppStorage("appearance") private var appearance: StudioAppearance = .system
    private let storage: Result<ModelContainer, Error>

    init() {
        let schema = Schema([StudioPalette.self, StudioProject.self, StudioCollection.self])
        #if DEBUG
        let ephemeral = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        let ephemeral = false
        #endif
        let configuration = ModelConfiguration(
            "CoStudio",
            schema: schema,
            isStoredInMemoryOnly: ephemeral,
            cloudKitDatabase: .none
        )
        storage = Result { try ModelContainer(for: schema, configurations: [configuration]) }
    }

    var body: some Scene {
        studioWindow
        #if os(macOS)
        Settings {
            Form { StudioAppearancePicker(selection: $appearance) }
                .formStyle(.grouped)
                .padding(10)
                .frame(width: 370)
                .preferredColorScheme(appearance.scheme)
        }
        #endif
    }

    private var studioWindow: some Scene {
        WindowGroup {
            Group {
                switch storage {
                case .success(let container):
                    StudioRootView()
                        .modelContainer(container)
                case .failure(let error):
                    ContentUnavailableView(
                        "Couldn’t open the library",
                        systemImage: "externaldrive.badge.exclamationmark",
                        description: Text("Your files have not been reset. Reopen CoStudio after checking available storage. \(error.localizedDescription)")
                    )
                }
            }
            .preferredColorScheme(appearance.scheme)
            .tint(StudioTheme.accent)
        }
        .commands { StudioCommands() }
        #if os(macOS)
        .defaultSize(width: 1210, height: 820)
        #endif
    }
}

enum StudioAppearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: Self { self }

    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct StudioAppearancePicker: View {
    @Binding var selection: StudioAppearance

    var body: some View {
        Picker("Appearance", selection: $selection) {
            ForEach(StudioAppearance.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
    }
}

struct StudioCommandActions {
    var navigate: (StudioDestination) -> Void
    var copyColor: () -> Void
}

private struct StudioCommandKey: FocusedValueKey {
    typealias Value = StudioCommandActions
}

extension FocusedValues {
    var studioCommands: StudioCommandActions? {
        get { self[StudioCommandKey.self] }
        set { self[StudioCommandKey.self] = newValue }
    }
}

struct StudioCommands: Commands {
    @FocusedValue(\.studioCommands) private var actions

    var body: some Commands {
        CommandMenu("Workspace") {
            ForEach(StudioDestination.allCases) { destination in
                Button(destination.title) { actions?.navigate(destination) }
                    .keyboardShortcut(destination.shortcut, modifiers: .command)
            }
            Divider()
            Button("Copy Active HEX") { actions?.copyColor() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
        }
    }
}
