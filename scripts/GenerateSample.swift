// Run from the repository root: swift scripts/GenerateSample.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let width = 1152
let height = 768
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: width * 4, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.translateBy(x: 0, y: CGFloat(height))
context.scaleBy(x: 1.5, y: -1.5)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func gradient(_ path: CGPath, _ colors: [UInt32], from: CGPoint, to: CGPoint) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = CGGradient(colorsSpace: space, colors: colors.map { color($0) } as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
}

func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

gradient(CGPath(rect: CGRect(x: 0, y: 0, width: 768, height: 512), transform: nil),
         [0xF4E8CC, 0xE3A282], from: point(105, 40), to: point(744, 440))

context.setFillColor(color(0xB77566))
context.fill(CGRect(x: 0, y: 380, width: 768, height: 132))
context.setFillColor(color(0xFCDEAD, alpha: 0.8))
context.fillEllipse(in: CGRect(x: 65, y: 76, width: 145, height: 145))
context.setFillColor(color(0x654739, alpha: 0.26))
context.fillEllipse(in: CGRect(x: 252, y: 408, width: 360, height: 42))
context.setFillColor(color(0x654739, alpha: 0.22))
context.fillEllipse(in: CGRect(x: 280, y: 414, width: 218, height: 21))

func stem(_ from: CGPoint, _ bend: CGPoint, _ to: CGPoint) {
    context.setStrokeColor(color(0x44553B))
    context.setLineWidth(3.2)
    context.setLineCap(.round)
    context.move(to: from)
    context.addQuadCurve(to: to, control: bend)
    context.strokePath()
}

func leaf(_ center: CGPoint, _ length: CGFloat, _ angle: CGFloat, _ fill: UInt32) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: angle)
    let shape = CGMutablePath()
    shape.move(to: point(-length / 2, 0))
    shape.addQuadCurve(to: point(length / 2, 0), control: point(3, length * 0.39))
    shape.addQuadCurve(to: point(-length / 2, 0), control: point(-8, -length * 0.52))
    context.setFillColor(color(fill))
    context.addPath(shape)
    context.fillPath()
    context.setStrokeColor(color(0xD7DD9C, alpha: 0.42))
    context.setLineWidth(1)
    context.move(to: point(-length * 0.42, 0))
    context.addQuadCurve(to: point(length * 0.45, 0), control: point(-3, -length * 0.07))
    context.strokePath()
    context.restoreGState()
}

stem(point(380, 303), point(385, 161), point(323, 97))
stem(point(392, 300), point(432, 161), point(509, 127))
stem(point(385, 298), point(372, 158), point(408, 58))
leaf(point(330, 102), 97, 0.68, 0x728B67)
leaf(point(358, 152), 83, -0.58, 0x799273)
leaf(point(330, 166), 95, 0.29, 0x5F795C)
leaf(point(365, 205), 68, 0.24, 0x9EAD71)
leaf(point(401, 78), 90, -1.03, 0x526B53)
leaf(point(379, 113), 73, 0.64, 0x879B65)
leaf(point(411, 139), 90, -0.50, 0x5D7E66)
leaf(point(503, 130), 99, -0.38, 0x6C906E)
leaf(point(467, 160), 78, -1.08, 0x4B6D56)
leaf(point(454, 192), 81, -0.35, 0x97AC77)
leaf(point(427, 228), 73, -0.26, 0x75996F)

let vessel = CGMutablePath()
vessel.move(to: point(344, 279))
vessel.addLine(to: point(426, 279))
vessel.addCurve(to: point(462, 357), control1: point(425, 320), control2: point(464, 312))
vessel.addCurve(to: point(422, 428), control1: point(462, 393), control2: point(444, 422))
vessel.addQuadCurve(to: point(345, 428), control: point(382, 436))
vessel.addCurve(to: point(304, 357), control1: point(318, 422), control2: point(300, 391))
vessel.addCurve(to: point(344, 279), control1: point(306, 313), control2: point(343, 319))
vessel.closeSubpath()
gradient(vessel, [0xE4A17F, 0xC46753, 0x82463E], from: point(278, 330), to: point(480, 395))

context.setFillColor(color(0xE5A787))
context.fillEllipse(in: CGRect(x: 343, y: 267, width: 84, height: 20))
context.setFillColor(color(0x76483C))
context.fillEllipse(in: CGRect(x: 351, y: 271, width: 68, height: 9))

let url = URL(fileURLWithPath: "Sources/CoStudio/Resources/StudioSample.png")
let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(output))
