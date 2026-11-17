import SwiftUI

struct ImageStudioCanvas: View {
    let image: CGImage
    let tool: ImageWorkspaceTool
    @Binding var zoom: Double
    @Binding var crop: ImageCrop
    let selectable: Bool
    let selected: CGPoint?
    let onSelect: (CGPoint) -> Void
    @GestureState private var magnification: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let ratio = min(
                max(1, geometry.size.width - 24) / Double(image.width),
                max(1, geometry.size.height - 24) / Double(image.height)
            )
            let displayedZoom = max(1, min(4, zoom * magnification))
            let size = CGSize(width: Double(image.width) * ratio * displayedZoom,
                              height: Double(image.height) * ratio * displayedZoom)
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    ColorCheckerboard(tile: 9)
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .interpolation(displayedZoom > 2 ? .none : .high)
                    if let selected {
                        selectionIndicator(at: selected, size: size)
                    }
                    if tool == .crop, selectable {
                        cropOutline(size: size)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { event in
                        if selectable && (tool == .sample || tool == .replace) {
                            onSelect(normalize(event.location, size: size))
                        }
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 2).onChanged { event in
                        guard selectable && tool == .crop else { return }
                        let start = normalize(event.startLocation, size: size)
                        let end = normalize(event.location, size: size)
                        crop = ImageCrop(
                            left: min(start.x, end.x), top: min(start.y, end.y),
                            right: max(start.x, end.x), bottom: max(start.y, end.y)
                        )
                    }, including: tool == .crop ? .all : .none
                )
                .simultaneousGesture(
                    MagnifyGesture()
                        .updating($magnification) { event, state, _ in state = event.magnification }
                        .onEnded { event in zoom = max(1, min(4, zoom * event.magnification)) }
                )
                .padding(12)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
        }
        .background(StudioTheme.canvas)
        .accessibilityLabel("Editing canvas, \(image.width) by \(image.height) pixels")
    }

    private func normalize(_ location: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: min(1, max(0, location.x / max(size.width, 1))),
            y: min(1, max(0, location.y / max(size.height, 1)))
        )
    }

    private func selectionIndicator(at point: CGPoint, size: CGSize) -> some View {
        Circle()
            .strokeBorder(.white, lineWidth: 2)
            .background(.black.opacity(0.35), in: Circle())
            .overlay(Circle().strokeBorder(.black.opacity(0.65), lineWidth: 0.5))
            .frame(width: 13, height: 13)
            .position(
                x: (point.x + 0.5) / Double(image.width) * size.width,
                y: (point.y + 0.5) / Double(image.height) * size.height
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func cropOutline(size: CGSize) -> some View {
        let box = CGRect(
            x: crop.left * size.width,
            y: crop.top * size.height,
            width: max(0, crop.right - crop.left) * size.width,
            height: max(0, crop.bottom - crop.top) * size.height
        )
        return Canvas { context, _ in
            var surround = Path(CGRect(origin: .zero, size: size))
            surround.addRect(box)
            context.fill(surround, with: .color(.black.opacity(0.51)), style: FillStyle(eoFill: true))
            context.stroke(Path(box.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
