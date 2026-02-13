import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

extension UIImage {
    /// Returns a new image with the orientation fixed to .up (pixels rotated to match display).
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
    
    /// Returns a new image resized to fit within the max dimension, maintaining aspect ratio.
    func resized(to maxDimension: CGFloat) -> UIImage {
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Don't upscale
        if newSize.width >= size.width {
            return self
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Efficiently downsamples image data using ImageIO to avoid high memory spikes.
    static func downsample(imageData: Data, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            return nil
        }
        
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    /// Removes the background from the image using on-device Vision framework.
    /// Requirements: iOS 17.0+
    func removeBackground() async throws -> UIImage? {
        // 1. Fix orientation first to ensure cgImage matches display orientation
        let fixed = self.fixedOrientation()
        guard let cgImage = fixed.cgImage else { return nil }
        
        // 2. Setup Vision request
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        do {
            try handler.perform([request])
        } catch {
            print("❌ Vision background removal failed: \(error)")
            return nil
        }
        
        guard let result = request.results?.first as? VNPixelBufferObservation else {
            return nil
        }
        
        // 3. Process the mask
        let maskPixelBuffer = result.pixelBuffer
        let ciImage = CIImage(cgImage: cgImage)
        var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // Scale mask to match original image size
        let scaleX = ciImage.extent.width / maskImage.extent.width
        let scaleY = ciImage.extent.height / maskImage.extent.height
        maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // 4. Apply mask using blend filter
        let filter = CIFilter.blendWithMask()
        filter.inputImage = ciImage
        filter.maskImage = maskImage
        filter.backgroundImage = CIImage.empty()
        
        guard let outputCIImage = filter.outputImage else { return nil }
        
        // 5. Render result back to UIImage
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let outputCGImage = context.createCGImage(outputCIImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
}
