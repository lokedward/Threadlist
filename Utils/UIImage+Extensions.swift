import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

extension UIImage {
    /// Returns a new image with the orientation fixed to .up (pixels rotated to match display).
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
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
        // Force evaluation with specific options if needed, but defaults are usually best
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
        
        // Convert pixel buffer to CIImage and ensure it's treated as a mask (usually grayscale)
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // 4. Transform and scale the mask to match the input image perfectly
        let scaleX = inputImage.extent.width / maskImage.extent.width
        let scaleY = inputImage.extent.height / maskImage.extent.height
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // 5. Create a solid white background (or cream)
        // This makes the "Cleanup" very obvious compared to transparency
        let backgroundColor = CIColor(red: 1, green: 1, blue: 1) // Pure White
        let background = CIImage(color: backgroundColor).cropped(to: inputImage.extent)
        
        // 6. Use the blend filter with alpha mask
        let filter = CIFilter.blendWithAlphaMask()
        filter.inputImage = inputImage
        filter.maskImage = scaledMask
        filter.backgroundImage = background
        
        guard let outputCIImage = filter.outputImage else {
            return nil
        }
        
        // 7. Create final CGImage
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let outputCGImage = context.createCGImage(outputCIImage, from: inputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage, scale: fixedImage.scale, orientation: .up)
    }
}
