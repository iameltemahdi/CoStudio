import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

enum ImageStudioError: LocalizedError {
    case invalidImage
    case invalidCrop
    case noSubject
    case renderFailed
    case exportFailed
    case invalidCatalog
    case missingOriginal
    case editsChanged

    var errorDescription: String? {
        switch self {
        case .invalidImage: "This file could not be decoded as an image."
        case .invalidCrop: "The crop must contain at least one pixel."
        case .noSubject: "Vision did not find a foreground subject in this photo."
        case .renderFailed: "CoStudio could not render this edit."
        case .exportFailed: "CoStudio could not encode the selected image format."
        case .invalidCatalog: "The image library could not be read. Its local files were preserved."
        case .missingOriginal: "The original image is missing from the local library."
        case .editsChanged: "This image was edited in another window. Open it again from the library to continue."
        }
    }
}

enum StudioImageFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"

    var id: Self { self }

    var contentType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .tiff: .tiff
        }
    }
}

struct ImageCrop: Codable, Equatable, Sendable {
    var left = 0.0
    var top = 0.0
    var right = 1.0
    var bottom = 1.0

    static let whole = ImageCrop()

    func pixelRect(width: Int, height: Int) -> CGRect {
        let edges = [left, top, right, bottom].map { min(1, max(0, $0)) }
        guard edges[0] < edges[2], edges[1] < edges[3] else { return .zero }
        let minX = floor(edges[0] * Double(width))
        let minY = floor(edges[1] * Double(height))
        let maxX = ceil(edges[2] * Double(width))
        let maxY = ceil(edges[3] * Double(height))
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

enum ImageBackground: Codable, Equatable, Sendable {
    case transparent
    case solid(StudioColor)
    case gradient(StudioColor, StudioColor)
}

enum ImageEdit: Codable, Equatable, Sendable {
    case rotateClockwise
    case crop(ImageCrop)
    case replace(source: StudioColor, target: StudioColor, tolerance: Double)
    case palette([StudioColor], intensity: Double)
    case isolate(ImageBackground)
}

struct ImageEditHistory: Equatable, Sendable {
    private(set) var applied: [ImageEdit] = []
    private(set) var undone: [ImageEdit] = []

    init(applied: [ImageEdit] = []) {
        self.applied = applied
    }

    mutating func append(_ edit: ImageEdit) {
        applied.append(edit)
        undone.removeAll()
    }

    mutating func undo() {
        if let edit = applied.popLast() {
            undone.append(edit)
        }
    }

    mutating func redo() {
        if let edit = undone.popLast() {
            applied.append(edit)
        }
    }
}

enum ImagePipeline {
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func load(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageStudioError.invalidImage
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.int32Value ?? 1
        if orientation == 1 { return image }
        return try draw(CIImage(cgImage: image).oriented(forExifOrientation: orientation))
    }

    static func render(_ original: CGImage, edits: [ImageEdit]) throws -> CGImage {
        try edits.reduce(original) { image, edit in
            try Task.checkCancellation()
            return try render(image, edit: edit)
        }
    }

    static func render(_ image: CGImage, edit: ImageEdit) throws -> CGImage {
        switch edit {
        case .rotateClockwise:
            return try draw(CIImage(cgImage: image).oriented(.right))
        case .crop(let crop):
            let rect = crop.pixelRect(width: image.width, height: image.height)
            guard rect.width > 0, rect.height > 0, let output = image.cropping(to: rect) else {
                throw ImageStudioError.invalidCrop
            }
            return output
        case .replace(let source, let target, let tolerance):
            return try replace(source, with: target, tolerance: tolerance, in: image)
        case .palette(let colors, let intensity):
            return try mapPalette(colors, intensity: intensity, in: image)
        case .isolate(let background):
            return try isolate(image, background: background)
        }
    }

    static func encode(_ image: CGImage, format: StudioImageFormat) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, format.contentType.identifier as CFString, 1, nil
        ) else { throw ImageStudioError.exportFailed }
        var source = image
        var options: [CFString: Any] = [:]
        if format == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = 0.95
            let foreground = CIImage(cgImage: image)
            let opaque = CIImage(color: .white).cropped(to: foreground.extent)
            source = try draw(foreground.composited(over: opaque))
        }
        CGImageDestinationAddImage(destination, source, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageStudioError.exportFailed }
        return output as Data
    }

    static func sample(_ image: CGImage, x: Int, y: Int) throws -> StudioColor {
        guard let pixel = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
            throw ImageStudioError.invalidCrop
        }
        return try ImageRaster(pixel).color(x: 0, y: 0)
    }

    static func loupe(_ image: CGImage, x: Int, y: Int, radius: Int = 5) -> CGImage? {
        let size = 2 * radius + 1
        let left = max(0, min(x - radius, image.width - size))
        let top = max(0, min(y - radius, image.height - size))
        return image.cropping(to: CGRect(
            x: left, y: top, width: min(size, image.width), height: min(size, image.height)
        ))
    }

    private static func isolate(_ image: CGImage, background: ImageBackground) throws -> CGImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw ImageStudioError.noSubject
        }
        let mask = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        let original = CIImage(cgImage: image)
        let extent = original.extent
        let backdrop: CIImage
        switch background {
        case .transparent:
            backdrop = CIImage(color: .clear).cropped(to: extent)
        case .solid(let color):
            backdrop = CIImage(color: ciColor(color)).cropped(to: extent)
        case .gradient(let first, let last):
            let gradient = CIFilter.linearGradient()
            gradient.point0 = CGPoint(x: extent.minX, y: extent.maxY)
            gradient.point1 = CGPoint(x: extent.maxX, y: extent.minY)
            gradient.color0 = ciColor(first)
            gradient.color1 = ciColor(last)
            guard let output = gradient.outputImage else { throw ImageStudioError.renderFailed }
            backdrop = output.cropped(to: extent)
        }
        let blend = CIFilter.blendWithMask()
        blend.inputImage = original
        blend.backgroundImage = backdrop
        blend.maskImage = CIImage(cvPixelBuffer: mask, options: [.colorSpace: NSNull()])
        guard let output = blend.outputImage else { throw ImageStudioError.renderFailed }
        return try draw(output.cropped(to: extent))
    }

    private static func ciColor(_ color: StudioColor) -> CIColor {
        CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha, colorSpace: colorSpace)
            ?? CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private static func draw(_ image: CIImage) throws -> CGImage {
        guard let output = context.createCGImage(image, from: image.extent.integral) else {
            throw ImageStudioError.renderFailed
        }
        return output
    }
}
