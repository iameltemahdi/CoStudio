import SwiftUI

extension StudioColor {
    var swiftUIColor: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    init(swiftUIColor: Color, environment: EnvironmentValues) {
        let resolved = swiftUIColor.resolve(in: environment)
        self.init(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue),
                  alpha: Double(resolved.opacity))
    }
}

struct ColorCopyButton: View {
    var value: String
    var title: String = "Copy"
    var compact = false
    @State private var copiedValue: String?

    var body: some View {
        Button {
            StudioClipboard.copy(value)
            copiedValue = value
        } label: {
            if compact {
                Image(systemName: copiedValue == value ? "checkmark" : "document.on.document")
            } else {
                Label(copiedValue == value ? "Copied" : title,
                      systemImage: copiedValue == value ? "checkmark" : "document.on.document")
            }
        }
        .accessibilityLabel(title)
        .help(title)
        .task(id: copiedValue) {
            guard copiedValue != nil else { return }
            do {
                try await Task.sleep(for: .seconds(1.5))
                copiedValue = nil
            } catch { /* A newer clipboard action replaced the feedback. */ }
        }
    }
}

struct ColorStudioPage<Content: View>: View {
    let title: String
    let subtitle: String
    let section: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WorkspaceHeader(title: title, subtitle: subtitle, eyebrow: section)
                content
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .padding(StudioTheme.padding)
            .frame(maxWidth: .infinity)
        }
    }
}

struct StudioSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
    }
}

struct ColorFilm: View {
    let color: StudioColor
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            if color.alpha < 1 { ColorCheckerboard() }
            color.swiftUIColor
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.black.opacity(0.12), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

struct ColorCheckerboard: View {
    var tile: CGFloat = 7

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            guard tile > 0 else { return }
            var alternate = Path()
            for row in 0..<Int(ceil(size.height / tile)) {
                for column in 0..<Int(ceil(size.width / tile)) where (row + column).isMultiple(of: 2) {
                    alternate.addRect(CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile,
                                             width: tile, height: tile))
                }
            }
            context.fill(alternate, with: .color(.black.opacity(0.12)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct StudioColorInput: View {
    let label: String
    @Binding var color: StudioColor
    @Environment(\.self) private var environment

    var body: some View {
        HStack(spacing: 8) {
            ColorPicker(label, selection: Binding(get: { color.swiftUIColor }, set: {
                color = StudioColor(swiftUIColor: $0, environment: environment)
            }))
            .labelsHidden()
            .accessibilityLabel(label)
            ColorFormatInput(format: .hex, color: $color, label: label + " HEX")
        }
    }
}

struct ColorFormatInput: View {
    let format: StudioColorFormat
    @Binding var color: StudioColor
    var label: String = "Color value"
    var showApply = false

    @FocusState private var focused: Bool
    @State private var draft = ""
    @State private var error = false
    @State private var committed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                TextField(format.inputHint, text: $draft)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .accessibilityLabel(label)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    #endif
                    .onSubmit(commit)
                if showApply {
                    Button("Apply", action: commit)
                        .buttonStyle(.bordered)
                        .disabled(draft == committed)
                }
            }
            if error {
                Text("Use \(format.inputHint).")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: color, initial: true) { _, _ in
            if !focused || !error { reset() }
        }
        .onChange(of: format) { _, _ in reset() }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
    }

    private func reset() {
        draft = format.string(for: color)
        committed = draft
        error = false
    }

    private func commit() {
        guard draft != committed else { return }
        guard let value = format.parse(draft, defaultAlpha: color.alpha) else {
            error = true
            return
        }
        color = value
        reset()
    }
}

struct ColorSwatchLine: View {
    let colors: [StudioColor]
    let action: (StudioColor) -> Void
    var showLabels = true
    var actionTitle = "Use"

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: showLabels ? 72 : 36), spacing: 8)], spacing: 8) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Button {
                    action(color)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        ColorFilm(color: color, cornerRadius: 6)
                            .frame(height: showLabels ? 47 : 36)
                        if showLabels {
                            Text(color.displayHex)
                                .font(.system(.caption2, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.displayHex)
                .help("\(actionTitle) \(color.displayHex)")
                .contextMenu {
                    Button("Copy HEX") { StudioClipboard.copy(color.displayHex) }
                }
            }
        }
    }
}
