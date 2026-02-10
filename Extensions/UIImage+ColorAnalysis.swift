// UIImage+ColorAnalysis.swift
// Color extraction and analysis for clothing items

import UIKit
import CoreGraphics

extension UIImage {
    /// Extract the dominant color from the image and return a human-readable color name
    func dominantColorName() -> String {
        guard let dominantColor = extractDominantColor() else {
            return "neutral" // fallback
        }
        
        return colorNameFromRGB(color: dominantColor)
    }
    
    // MARK: - Private Helpers
    
    private func extractDominantColor() -> UIColor? {
        // Downscale image for performance
        guard let smallImage = downsample(to: CGSize(width: 100, height: 100)),
              let cgImage = smallImage.cgImage else {
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // Create color space and bitmap context
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        
        // Draw image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return nil }
        
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        
        // Color counting with k-means approach (simplified)
        var colorCounts: [String: (count: Int, r: Int, g: Int, b: Int)] = [:]
        
        // Sample every 4th pixel for performance
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let offset = (y * width + x) * bytesPerPixel
                
                let r = Int(pixels[offset])
                let g = Int(pixels[offset + 1])
                let b = Int(pixels[offset + 2])
                let a = Int(pixels[offset + 3])
                
                // Skip transparent pixels
                guard a > 128 else { continue }
                
                // Bucket colors to reduce noise (round to nearest 32)
                let bucketSize = 32
                let bucketR = (r / bucketSize) * bucketSize
                let bucketG = (g / bucketSize) * bucketSize
                let bucketB = (b / bucketSize) * bucketSize
                
                let key = "\(bucketR)-\(bucketG)-\(bucketB)"
                
                if var existing = colorCounts[key] {
                    existing.count += 1
                    colorCounts[key] = existing
                } else {
                    colorCounts[key] = (count: 1, r: bucketR, g: bucketG, b: bucketB)
                }
            }
        }
        
        // Find most common color
        guard let dominant = colorCounts.max(by: { $0.value.count < $1.value.count }) else {
            return nil
        }
        
        let r = CGFloat(dominant.value.r) / 255.0
        let g = CGFloat(dominant.value.g) / 255.0
        let b = CGFloat(dominant.value.b) / 255.0
        
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    private func colorNameFromRGB(color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Convert to 0-255 scale
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        
        // Calculate brightness and saturation
        let brightness = (r + g + b) / 3
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let saturation = maxVal == 0 ? 0 : (maxVal - minVal) * 100 / maxVal
        
        // Achromatic colors (black, white, grey)
        if saturation < 15 {
            if brightness < 50 {
                return "black"
            } else if brightness > 200 {
                return "white"
            } else if brightness > 150 {
                return "light grey"
            } else if brightness > 100 {
                return "grey"
            } else {
                return "dark grey"
            }
        }
        
        // Determine hue-based color
        let hue: String
        
        if r > g && r > b {
            // Red dominant
            if g > b {
                // Reddish-yellow (orange/red)
                if r - g < 50 {
                    hue = "orange"
                } else {
                    hue = "red"
                }
            } else {
                // Reddish-blue (pink/magenta)
                if b > 150 {
                    hue = "magenta"
                } else if r > 200 && g < 100 {
                    hue = "red"
                } else {
                    hue = "pink"
                }
            }
        } else if g > r && g > b {
            // Green dominant
            if r > b {
                // Greenish-yellow
                if g - r < 50 {
                    hue = "yellow"
                } else {
                    hue = "lime green"
                }
            } else {
                // Pure green or cyan
                if b > 100 {
                    hue = "teal"
                } else {
                    hue = "green"
                }
            }
        } else {
            // Blue dominant
            if r > g {
                // Blueish-red (purple)
                hue = "purple"
            } else if g > r {
                // Blueish-green (cyan)
                hue = "cyan"
            } else {
                // Pure blue
                hue = "blue"
            }
        }
        
        // Add brightness modifiers
        if brightness < 80 {
            return "dark \(hue)"
        } else if brightness > 180 {
            return "light \(hue)"
        } else {
            return hue
        }
    }
    
    private func downsample(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
}
