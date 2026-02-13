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
        // 1. Ensure we have a fixed orientation image for processing
        let fixedImage = self.fixedOrientation()
        guard let cgImage = fixedImage.cgImage else { return nil }
        
        // 2. Setup Vision request for foreground instance mask
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("❌ Vision background removal error: \(error)")
            return nil
        }
        
        guard let result = request.results?.first as? VNPixelBufferObservation else {
            print("⚠️ Vision: No foreground detected")
            return nil
        }
        
        // 3. Create CIImages for original and mask
        let inputImage = CIImage(cgImage: cgImage)
        let maskPixelBuffer = result.pixelBuffer
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // 4. Transform and scale the mask to match the input image perfectly
        let scaleX = inputImage.extent.width / maskImage.extent.width
        let scaleY = inputImage.extent.height / maskImage.extent.height
        let scaleTransform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let scaledMask = maskImage.transformed(by: scaleTransform)
        
        // 5. Use the blend filter with alpha mask
        // Note: Vision masks are grayscale where 1.0 is foreground
        let parameters: [String: Any] = [
            kCIInputImageKey: inputImage,
            kCIInputMaskImageKey: scaledMask
        ]
        
        guard let filter = CIFilter(name: "CIBlendWithAlphaMask", parameters: parameters),
              let outputCIImage = filter.outputImage else {
            return nil
        }
        
        // 6. Create final CGImage
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let outputCGImage = context.createCGImage(outputCIImage, from: inputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
}
