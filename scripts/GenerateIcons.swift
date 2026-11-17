// Run from the repository root: swift scripts/GenerateIcons.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: "Sources/CoStudio/Resources/Assets.xcassets", isDirectory: true)
let ink = CGColor(srgbRed: 34 / 255, green: 39 / 255, blue: 29 / 255, alpha: 1)
let lime = CGColor(srgbRed: 217 / 255, green: 241 / 255, blue: 119 / 255, alpha: 1)
let muted = CGColor(srgbRed: 106 / 255, green: 125 / 255, blue: 78 / 255, alpha: 1)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func line(_ points: [CGPoint], color: CGColor, width: CGFloat, context: CGContext) {
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.beginPath()
    context.addLines(between: points)
    context.strokePath()
}

func drawMark(_ context: CGContext) {
    context.setStrokeColor(muted)
    context.setLineWidth(1.1)
    context.strokeEllipse(in: CGRect(x: 30, y: 56, width: 50, height: 50))

    context.setStrokeColor(lime)
    context.setLineWidth(4.9)
    context.strokeEllipse(in: CGRect(x: 22, y: 48, width: 66, height: 66))

    line([CGPoint(x: 21, y: 81), CGPoint(x: 28, y: 81)], color: lime, width: 2.4, context: context)
    line([CGPoint(x: 55, y: 107), CGPoint(x: 55, y: 115)], color: lime, width: 2.4, context: context)

    // The same axis aligns the eyedropper cap, barrel, stem, and sample.
    context.saveGState()
    context.translateBy(x: 58, y: 78)
    context.rotate(by: -.pi / 4)

    let barrel = CGPath(roundedRect: CGRect(x: -6, y: -6, width: 63, height: 12), cornerWidth: 6, cornerHeight: 6, transform: nil)
    context.setStrokeColor(ink)
    context.setLineWidth(5.2)
    context.addPath(barrel)
    context.strokePath()
    context.setFillColor(lime)
    context.addPath(barrel)
    context.fillPath()

    let handle = CGPath(roundedRect: CGRect(x: 35, y: -10, width: 38, height: 20), cornerWidth: 9, cornerHeight: 9, transform: nil)
    context.setStrokeColor(ink)
    context.setLineWidth(4)
    context.addPath(handle)
    context.strokePath()
    context.setFillColor(lime)
    context.addPath(handle)
    context.fillPath()

    line([CGPoint(x: 40, y: -9), CGPoint(x: 40, y: 9)], color: ink, width: 2.7, context: context)
    line([CGPoint(x: 9, y: 0), CGPoint(x: 34, y: 0)], color: ink, width: 3.1, context: context)
    context.restoreGState()
}

enum Artwork { case iPad, mac, glyph }

func render(_ size: Int, _ artwork: Artwork, to url: URL) {
    let alpha: CGImageAlphaInfo = artwork == .iPad ? .noneSkipLast : .premultipliedLast
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: space, bitmapInfo: alpha.rawValue) else {
        fatalError("Could not create artwork canvas")
    }
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: CGFloat(size) / 128, y: -CGFloat(size) / 128)
    context.setFillColor(ink)

    switch artwork {
    case .iPad:
        context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
    case .mac:
        context.addPath(CGPath(roundedRect: CGRect(x: 7, y: 7, width: 114, height: 114), cornerWidth: 25, cornerHeight: 25, transform: nil))
        context.fillPath()
        context.translateBy(x: 10, y: 10)
        context.scaleBy(x: 0.84, y: 0.84)
    case .glyph:
        break
    }
    drawMark(context)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "Could not write \(url.path)")
}

func write(_ json: [String: Any], to url: URL) throws {
    let bytes = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try (bytes + Data([10])).write(to: url)
}

let apps = root.appendingPathComponent("AppIcon.appiconset")
let glyph = root.appendingPathComponent("StudioGlyph.imageset")
for directory in [apps, glyph] {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
}
let info: [String: Any] = ["author": "xcode", "version": 1]
try write(["info": info], to: root.appendingPathComponent("Contents.json"))

render(1024, .iPad, to: apps.appendingPathComponent("CoStudio-iPad.png"))
var slots = [["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "CoStudio-iPad.png"]]
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "mac-\(points)@\(scale)x.png"
        render(points * scale, .mac, to: apps.appendingPathComponent(filename))
        slots.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
    }
}
try write(["images": slots, "info": info], to: apps.appendingPathComponent("Contents.json"))
render(256, .glyph, to: glyph.appendingPathComponent("glyph.png"))
try write(["images": [["idiom": "universal", "filename": "glyph.png"]], "info": info], to: glyph.appendingPathComponent("Contents.json"))
