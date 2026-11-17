import SwiftUI

struct CreativeColorControl: View {
    var title: String
    @Binding var value: StudioColor
    @Environment(\.self) private var environment

    var body: some View {
        ColorPicker(title, selection: Binding(
            get: { value.swiftUIColor },
            set: { value = StudioColor(swiftUIColor: $0, environment: environment) }
        ), supportsOpacity: true)
        .labelsHidden()
        .accessibilityLabel(title)
    }
}

struct CreativeHexField: View {
    @Binding var value: StudioColor
    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var invalid = false

    var body: some View {
        TextField("HEX", text: $text)
            .textFieldStyle(.plain)
            .focused($focused)
            .foregroundStyle(invalid ? Color.red : Color.primary)
            .font(.system(.body, design: .monospaced).weight(.medium))
            .accessibilityLabel(invalid ? "Invalid hex color" : "Hex color")
            .help("Enter a 3-, 4-, 6-, or 8-digit HEX color")
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            #endif
            .onAppear { text = value.exportHex }
            .onChange(of: value) { _, updated in
                if !focused {
                    text = updated.exportHex
                    invalid = false
                }
            }
            .onChange(of: focused) { _, active in
                if !active { commit() }
            }
            .onSubmit { commit() }
    }

    private func commit() {
        guard let parsed = StudioColor(hex: text) else {
            invalid = true
            return
        }
        value = parsed
        text = value.exportHex
        invalid = false
    }
}

struct CreativePanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1) }
    }
}
