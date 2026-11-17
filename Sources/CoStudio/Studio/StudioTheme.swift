import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum StudioTheme {
    static let canvas = adaptive(light: 0xF6F5F0, dark: 0x191B18)
    static let panel = adaptive(light: 0xFDFCFA, dark: 0x222520)
    static let line = adaptive(light: 0xE5E3DA, dark: 0x34382F)
    static let accent = adaptive(light: 0x46602D, dark: 0xC9E581)
    static let brand = rgb(0xD9F177)
    static let ink = rgb(0x22271D)
    static let padding: CGFloat = 27

    static func rgb(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255
        )
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        func channels(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255)
        }
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let values = channels(appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
            return NSColor(srgbRed: values.0, green: values.1, blue: values.2, alpha: 1)
        })
        #else
        return Color(uiColor: UIColor { traits in
            let values = channels(traits.userInterfaceStyle == .dark ? dark : light)
            return UIColor(red: values.0, green: values.1, blue: values.2, alpha: 1)
        })
        #endif
    }
}

struct WorkspaceHeader: View {
    let title: String
    let subtitle: String
    let eyebrow: String

    init(title: String, subtitle: String, eyebrow: String = "WORKSPACE") {
        self.title = title
        self.subtitle = subtitle
        self.eyebrow = eyebrow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .tracking(1.7)
                .foregroundStyle(StudioTheme.accent)
            Text(title)
                .font(.system(.largeTitle).weight(.semibold))
                .tracking(-0.9)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StudioMark: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24).fill(StudioTheme.ink)
            Image("StudioGlyph")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(size * 0.12)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum StudioClipboard {
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
