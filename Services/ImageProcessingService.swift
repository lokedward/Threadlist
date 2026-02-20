import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

class ImageProcessingService {
    static let shared = ImageProcessingService()
    
    private let context = CIContext()
    
    private init() {}
    
    /// Processes an array of UIImages in parallel, removing backgrounds.
    func processClothingImages(_ images: [UIImage]) async throws -> [UIImage] {
        return try await withThrowingTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let processed = try await self.removeBackground(from: image)
                    return (index, processed)
                }
            }
            
            var results: [UIImage?] = Array(repeating: nil, count: images.count)
            for try await (index, image) in group {
                results[index] = image
            }
            
            return results.compactMap { $0 }
        }
    }
    
    /// Attempts to remove the background using Vision. Falls back to a warm film filter on failure or empty mask.
    private func removeBackground(from image: UIImage) async throws -> UIImage {
        // Aesthetic fallback preserves color, adds a warm 'editorial' fade
        let applyFallback: () -> UIImage = {
            return self.applyWarmAestheticFilter(to: image) ?? image
        }
        
        guard let cgImage = image.cgImage else {
            return applyFallback()
        }
        
        if #available(iOS 17.0, *) {
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            
            do {
                try handler.perform([request])
                guard let result = request.results?.first else {
                    return applyFallback()
                }
                
                // Ensure there is actually a foreground to mask
                let instances = result.allInstances
                guard !instances.isEmpty else {
                    return applyFallback()
                }
                
                let mask = try result.generateScaledMaskForImage(forInstances: instances, from: handler)
                let maskCI = CIImage(cvPixelBuffer: mask)
                let originalCI = CIImage(cgImage: cgImage)
                
                let filter = CIFilter.blendWithMask()
                filter.inputImage = originalCI
                filter.maskImage = maskCI
                filter.backgroundImage = CIImage(color: .clear)
                
                guard let output = filter.outputImage,
                      let finalCGImage = self.context.createCGImage(output, from: output.extent) else {
                    return applyFallback()
                }
                
                return UIImage(cgImage: finalCGImage, scale: image.scale, orientation: image.imageOrientation)
                
            } catch {
                print("Vision masking failed: \(error)")
                return applyFallback()
            }
        } else {
            return applyFallback()
        }
    }
    
    /// Applies a warm, sophisticated "film" fade. 
    /// Great for fallbacks so items look like stylized moodboard photos rather than mistakes.
    private func applyWarmAestheticFilter(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // 1. Warmth (Color Controls - Slight saturation boost, slight brightness)
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = 0.95
        colorControls.contrast = 1.05
        colorControls.brightness = 0.02
        guard let step1 = colorControls.outputImage else { return nil }
        
        // 2. Vintage Fade / Warm tone (Sepia tone at very low intensity)
        let sepia = CIFilter.sepiaTone()
        sepia.inputImage = step1
        sepia.intensity = 0.15
        guard let step2 = sepia.outputImage,
              let cgImage = context.createCGImage(step2, from: step2.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
