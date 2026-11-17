import SwiftUI

struct ContrastWorkspace: View {
    @Binding var selection: StudioColor
    @State private var background = StudioColor(red: 0.9725, green: 0.9569, blue: 0.9098)
    @State private var sample = "The quick brown fox jumps over the lazy dog."
    @State private var target: ContrastReport.Criterion = .normalAA

    private var report: ContrastReport { ContrastReport(foreground: selection, background: background) }

    var body: some View {
        ColorStudioPage(title: "Contrast Checker", subtitle: "Check a foreground and background against WCAG 2.2.", section: "CHECK") {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    preview.frame(minWidth: 285, maxWidth: .infinity)
                    controls.frame(width: 270)
                }
                VStack(alignment: .leading, spacing: 20) { preview; controls }
            }
            results
            Divider()
            suggestions
            Text("Translucent colors are composited over white. WCAG large text is at least 18 pt regular or 14 pt bold.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TEXT PREVIEW").font(.system(.caption2, design: .monospaced).weight(.semibold))
            Text("Aa")
                .font(.system(size: 88, weight: .medium))
                .accessibilityHidden(true)
            Text(sample.isEmpty ? "The quick brown fox jumps over the lazy dog." : sample)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 213, alignment: .leading)
        .padding(19)
        .foregroundStyle(report.renderedForeground.swiftUIColor)
        .background(report.renderedBackground.swiftUIColor, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 11) {
            StudioSectionTitle(title: "Foreground")
            StudioColorInput(label: "Foreground", color: $selection)
            StudioSectionTitle(title: "Background")
            StudioColorInput(label: "Background", color: $background)
            Button {
                let oldForeground = selection
                selection = background
                background = oldForeground
            } label: {
                Label("Swap colors", systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.bordered)
            Divider()
            TextField("Preview text", text: $sample)
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.panel, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioTheme.line, lineWidth: 1))
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 11) {
                Text(String(format: "%.3f : 1", (report.ratio * 1000 + 1e-10).rounded(.down) / 1000))
                    .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                    .accessibilityLabel("Contrast ratio \(StudioColorFormat.decimal(report.ratio, precision: 4)) to 1")
                Text("Contrast ratio").font(.subheadline).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 9)], spacing: 8) {
                ForEach(ContrastReport.Criterion.allCases) { criterion in
                    let passes = report.passes(criterion)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(criterion.size).font(.caption).foregroundStyle(.secondary)
                        Label("\(criterion.title) \(passes ? "Pass" : "Fail")",
                              systemImage: passes ? "checkmark.circle" : "xmark.circle")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(passes ? StudioTheme.accent : Color.primary)
                        Text("≥ \(StudioColorFormat.decimal(criterion.threshold)) : 1")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StudioTheme.panel, in: .rect(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(StudioTheme.line, lineWidth: 1))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StudioSectionTitle(title: "Foreground suggestions")
                Spacer()
                Picker("Target contrast", selection: $target) {
                    ForEach(ContrastReport.Criterion.allCases) {
                        Text("\($0.size) · \($0.title)").tag($0)
                    }
                }
                .labelsHidden().fixedSize()
            }
            if report.passes(target) {
                Label("This pair meets the selected target.", systemImage: "checkmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                let alternatives = ContrastReport.suggestions(foreground: selection, background: background, threshold: target.threshold)
                if alternatives.isEmpty {
                    Text("Increase foreground opacity or change the background to reach this target.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ColorSwatchLine(colors: alternatives) { selection = $0 }
                }
            }
        }
    }
}
