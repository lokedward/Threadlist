import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

class ImageProcessingService {
    static let shared = ImageProcessingService()
    
    private let context = CIContext()
    
    private init() {}
    
    /// Processes an array of UIImages in parallel, applying a stylized presentation filter.
    func processClothingImages(_ images: [UIImage]) async throws -> [UIImage] {
        return try await withThrowingTaskGroup(of: (Int, UIImage).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let processed = self.applyWarmAestheticFilter(to: image)
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
    
    /// Applies a warm, sophisticated "film" fade. 
    /// Great for stylized moodboard photos so native images feel curated rather than raw.
    private func applyWarmAestheticFilter(to image: UIImage) -> UIImage {
        // Aesthetic fallback preserves color, adds a warm 'editorial' fade
        guard let ciImage = CIImage(image: image) else { return image }
        
        // 1. Warmth (Color Controls - Slight saturation boost, slight brightness)
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = 0.95
        colorControls.contrast = 1.05
        colorControls.brightness = 0.02
        guard let step1 = colorControls.outputImage else { return image }
        
        // 2. Vintage Fade / Warm tone (Sepia tone at very low intensity)
        let sepia = CIFilter.sepiaTone()
        sepia.inputImage = step1
        sepia.intensity = 0.15
        guard let step2 = sepia.outputImage,
              let cgImage = context.createCGImage(step2, from: step2.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
