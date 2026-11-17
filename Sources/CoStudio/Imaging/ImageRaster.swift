import CoreGraphics
import Foundation

struct ImageRaster {
    let width: Int
    let height: Int
    var bytes: [UInt8]

    init(_ image: CGImage, width: Int? = nil, height: Int? = nil) throws {
        self.width = width ?? image.width
        self.height = height ?? image.height
        let rowBytes = self.width * 4
        let bitmap = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil, width: self.width, height: self.height,
            bitsPerComponent: 8, bytesPerRow: rowBytes,
            space: ImagePipeline.colorSpace, bitmapInfo: bitmap
        ), let buffer = context.data else { throw ImageStudioError.renderFailed }
        context.interpolationQuality = .medium
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
        bytes = Array(UnsafeBufferPointer(
            start: buffer.assumingMemoryBound(to: UInt8.self), count: rowBytes * self.height
        ))
    }

    func color(x: Int, y: Int) -> StudioColor {
        let index = (y * width + x) * 4
        let alpha = Double(bytes[index + 3])
        guard alpha > 0 else { return StudioColor(red: 0, green: 0, blue: 0, alpha: 0) }
        return StudioColor(
            red: Double(bytes[index]) / alpha,
            green: Double(bytes[index + 1]) / alpha,
            blue: Double(bytes[index + 2]) / alpha,
            alpha: alpha / 255
        )
    }

    func makeImage() throws -> CGImage {
        let bitmap = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: ImagePipeline.colorSpace,
                bitmapInfo: bitmap, provider: provider, decode: nil,
                shouldInterpolate: true, intent: .defaultIntent
              ) else { throw ImageStudioError.renderFailed }
        return image
    }

    mutating func transform(_ body: (SIMD3<Double>) -> SIMD3<Double>) throws {
        for y in 0..<height {
            if y.isMultiple(of: 64) { try Task.checkCancellation() }
            for x in 0..<width {
                let index = (y * width + x) * 4
                let alpha = Double(bytes[index + 3])
                guard alpha > 0 else { continue }
                let rgb = SIMD3(Double(bytes[index]), Double(bytes[index + 1]), Double(bytes[index + 2])) / alpha
                let edited = body(rgb)
                bytes[index] = UInt8((min(1, max(0, edited.x)) * alpha).rounded())
                bytes[index + 1] = UInt8((min(1, max(0, edited.y)) * alpha).rounded())
                bytes[index + 2] = UInt8((min(1, max(0, edited.z)) * alpha).rounded())
            }
        }
    }
}

extension ImagePipeline {
    static func replace(
        _ source: StudioColor, with target: StudioColor, tolerance: Double, in image: CGImage
    ) throws -> CGImage {
        var raster = try ImageRaster(image)
        let origin = SIMD3(source.red, source.green, source.blue)
        let difference = SIMD3(target.red, target.green, target.blue) - origin
        let radius = max(1 / 255.0, tolerance) * sqrt(3)
        try raster.transform { rgb in
            let delta = rgb - origin
            let distance = sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z)
            let blend = 1 - min(1, max(0, (distance - radius * 0.55) / (radius * 0.45)))
            return rgb + difference * (blend * blend * (3 - 2 * blend))
        }
        return try raster.makeImage()
    }

    static func mapPalette(_ colors: [StudioColor], intensity: Double, in image: CGImage) throws -> CGImage {
        guard colors.count >= 2 else { return image }
        var raster = try ImageRaster(image)
        let points = colors.map { SIMD3($0.red, $0.green, $0.blue) }
        let mix = min(1, max(0, intensity))
        try raster.transform { rgb in
            let gray = rgb.x * 0.2126 + rgb.y * 0.7152 + rgb.z * 0.0722
            let location = min(1, max(0, gray)) * Double(points.count - 1)
            let index = min(points.count - 2, Int(location))
            let weight = location - Double(index)
            let graded = points[index] + (points[index + 1] - points[index]) * weight
            return rgb + (graded - rgb) * mix
        }
        return try raster.makeImage()
    }

    /// Cluster a downsampled image in weighted sRGB buckets. Transparent pixels
    /// contribute in proportion to their alpha and never become a palette color.
    static func dominantColors(in image: CGImage, count: Int) throws -> [StudioColor] {
        guard count > 0 else { return [] }
        let scale = min(1, 128.0 / Double(max(image.width, image.height)))
        let raster = try ImageRaster(
            image, width: max(1, Int(Double(image.width) * scale)),
            height: max(1, Int(Double(image.height) * scale))
        )
        var buckets: [Int: Bucket] = [:]
        for y in 0..<raster.height {
            try Task.checkCancellation()
            for x in 0..<raster.width {
                let color = raster.color(x: x, y: y)
                guard color.alpha >= 0.05 else { continue }
                let rgb = SIMD3(color.red, color.green, color.blue)
                let key = Int(rgb.x * 15) * 256 + Int(rgb.y * 15) * 16 + Int(rgb.z * 15)
                buckets[key, default: .init()].add(rgb, weight: color.alpha)
            }
        }
        let samples = buckets.sorted { $0.key < $1.key }.map(\.value)
        guard let first = samples.max(by: { $0.weight < $1.weight }) else { return [] }
        var centers = [first.average]
        while centers.count < min(count, samples.count) {
            var best: (sample: Bucket, score: Double)?
            for sample in samples {
                let distance = centers.map { squaredDistance(sample.average, $0) }.min() ?? 0
                let score = distance * sqrt(sample.weight)
                if best == nil || score > best!.score { best = (sample, score) }
            }
            guard let best, best.score > 0 else { break }
            centers.append(best.sample.average)
        }

        var clusters: [Bucket] = []
        for _ in 0..<8 {
            try Task.checkCancellation()
            clusters = Array(repeating: Bucket(), count: centers.count)
            for sample in samples {
                let nearest = centers.indices.min {
                    squaredDistance(centers[$0], sample.average) < squaredDistance(centers[$1], sample.average)
                } ?? 0
                clusters[nearest].add(sample.average, weight: sample.weight)
            }
            for index in centers.indices where clusters[index].weight > 0 {
                centers[index] = clusters[index].average
            }
        }

        return clusters.filter { $0.weight > 0 }
            .sorted { $0.weight > $1.weight }
            .map { StudioColor(red: $0.average.x, green: $0.average.y, blue: $0.average.z) }
    }

    private static func squaredDistance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let delta = a - b
        return delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
    }
}

private struct Bucket {
    var sum = SIMD3<Double>.zero
    var weight = 0.0
    var average: SIMD3<Double> { sum / weight }

    mutating func add(_ rgb: SIMD3<Double>, weight: Double) {
        sum += rgb * weight
        self.weight += weight
    }
}
