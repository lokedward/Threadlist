import SwiftUI
import UIKit

struct ScrollableCropperView: UIViewControllerRepresentable {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let cropperVC = CropperViewController(image: image, onSave: onSave, onCancel: onCancel)
        let nav = UINavigationController(rootViewController: cropperVC)
        nav.navigationBar.scrollEdgeAppearance = nav.navigationBar.standardAppearance
        // Dark theme for the cropper
        nav.navigationBar.barStyle = .black
        nav.navigationBar.tintColor = .white
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

class CropperViewController: UIViewController, UIScrollViewDelegate {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.delegate = self
        sv.minimumZoomScale = 0.5 // Allow zooming out (Canvas mode)
        sv.maximumZoomScale = 5.0
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .black
        sv.contentInsetAdjustmentBehavior = .never
        return sv
    }()
    
    private lazy var imageView: UIImageView = {
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .black // Match background
        iv.isUserInteractionEnabled = true
        return iv
    }()
    
    private lazy var overlayView: UIView = {
        let v = CropperOverlayView()
        v.isUserInteractionEnabled = false // Pass touches to scrollview
        return v
    }()
    
    // The "Crop Box" is defined as a specific square in the center of the screen
    private var cropRect: CGRect {
        let side = min(view.bounds.width, view.bounds.height) - 40
        let x = (view.bounds.width - side) / 2
        let y = (view.bounds.height - side) / 2
        return CGRect(x: x, y: y, width: side, height: side)
    }
    
    init(image: UIImage, onSave: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.onSave = onSave
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        view.addSubview(overlayView)
        
        setupToolbar()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Layout ScrollView to fill screen
        scrollView.frame = view.bounds
        overlayView.frame = view.bounds
        
        // Pass crop box to overlay
        if let overlay = overlayView as? CropperOverlayView {
            overlay.cropRect = cropRect
            overlay.setNeedsDisplay()
        }
        
        // Layout ImageView
        // We want the image to match its intrinsic size (pixels) initially?
        // Or fit the crop box?
        // Let's set the imageView logic once
        if imageView.frame == .zero {
            resetZoom()
        }
        
        // Center content
        centerContent()
        
        // Set content inset so we can scroll the image "into" the center crop box
        // The "visible area" is the simple cropRect.
        // We need users to be able to scroll the TOP LEFT of the image to the CENTER of the crop box?
        // Actually, Apple's PHOTOS app approach:
        // ScrollView is FULL SCREEN.
        // ContentInset pads the scroll view so that the content (image) can be scrolled
        // such that its edges align with the Crop Rect edges.
        
        updateContentInset()
    }
    
    private func setupToolbar() {
        title = "Crop Photo"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(handleCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(handleDone))
        
        let resetButton = UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(handleReset))
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            resetButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        ]
        navigationController?.setToolbarHidden(false, animated: false)
        navigationController?.toolbar.barStyle = .black
        navigationController?.toolbar.tintColor = .white
    }
    
    private func resetZoom() {
        // Reset image frame to intrinsic size
        imageView.sizeToFit()
        scrollView.contentSize = imageView.bounds.size
        
        // Calculate min scale to fill crop box (Aspect Fill)
        // OR fit crop box (Aspect Fit)?
        // User asked for "canvas style" freedom. "Fit" is a safer default so they see everything.
        // But traditionally croppers default to "Fill" to avoid black bars.
        // Let's default to "Fill" but allow zooming out.
        
        let crop = cropRect
        let imgW = image.size.width
        let imgH = image.size.height
        
        let scaleW = crop.width / imgW
        let scaleH = crop.height / imgH
        
        // Fill: max(scaleW, scaleH)
        // Fit: min(scaleW, scaleH)
        let fillScale = max(scaleW, scaleH)
        
        scrollView.zoomScale = fillScale
        
        // Center the image initially
        // (Handled by centerContent + updateContentInset)
    }
    
    private func updateContentInset() {
        // We need contentInset to be such that we can scroll the image edges to the crop box edges.
        // Left Inset = Crop.minX
        // Right Inset = View.width - Crop.maxX
        // Top Inset = Crop.minY
        // Bottom Inset = View.height - Crop.maxY
        
        let crop = cropRect
        let hInset = crop.minX
        let vInset = crop.minY // Since it's centered, top/bottom are same
        let bottomInset = view.bounds.height - crop.maxY
        let rightInset = view.bounds.width - crop.maxX
        
        scrollView.contentInset = UIEdgeInsets(top: vInset, left: hInset, bottom: bottomInset, right: rightInset)
    }
    
    private func centerContent() {
        // This keeps the image centered in the scrollview content when it's smaller than the bounds
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        
        // Center horizontally
        if frameToCenter.size.width < boundsSize.width {
            // If we are zoomed out small, we specifically want it centered relative to the whole view?
            // Actually, if we use contentInset for the crop box, we might fight with this.
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2.0
        } else {
            frameToCenter.origin.x = 0
        }
        
        // Center vertically
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2.0
        } else {
            frameToCenter.origin.y = 0
        }
        
        // Wait, standard UIScrollView centering logic (subclassing layoutSubviews or hacking center)
        // But with `contentInset` active, coordinate system shifts.
        // Simplest way for "Canvas" feel:
        // When Zoomed Out < CropBox, we want image inside CropBox.
        // The ContentInset approach sets the "Frame" of the scrollable area to the CropBox.
        // So centering in the CropBox is centering in the viewport minus insets.
        
        // Let's rely on standard contentInset logic first.
        // If image < cropBox, we want it centered in cropBox.
        // cropBox is (inset.left ... view.width-inset.right).
        
        // Actually, if we just want "Canvas" freedom:
        // Set contentInset such that you can scroll image far away.
        // Using "Fill Screen ScrollView + Overlay" is standard.
        // We just need to make sure `scrollViewDidZoom` adjusts visible center?
        
        // Let's stick to: Let ScrollView handle panning.
        // When image is smaller than content size?
        
        // If I zoom out way far (tiny image).
        // contentSize is tiny.
        // ScrollView bounds is huge.
        // iOS pins to top-left (0,0).
        // (0,0) is shifted by contentInset.
        
        // Correct logic for centering in ScrollView:
        let crop = cropRect
        // Effective scroll area size
        // If content is smaller than crop area?
        
        if frameToCenter.size.width < crop.width {
             // Center in crop rect X
             // Not just scrollview X
        }
        
        // Actually, simpler logic for "Canvas":
        // Don't use contentInset for bounds.
        // Use a container view inside ScrollView?
        // Or just let the user pan.
        // If we want it to "Center" when smaller:
        
        let contentSize = scrollView.contentSize
        let offsetX = max((boundsSize.width - contentSize.width) * 0.5, 0)
        let offsetY = max((boundsSize.height - contentSize.height) * 0.5, 0)
        
        // But we want to center in CROP rect (which matches screen center in our case)
        // Since crop rect is centered in bounds, centering in bounds == centering in crop rect.
        // So standard centering logic works!
        
        imageView.center = CGPoint(
            x: scrollView.contentSize.width * 0.5 + offsetX,
            y: scrollView.contentSize.height * 0.5 + offsetY
        )
    }
    
    // UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
    }
    
    @objc func handleCancel() {
        onCancel()
    }
    
    @objc func handleReset() {
        UIView.animate(withDuration: 0.3) {
            self.resetZoom()
        }
    }
    
    @objc func handleDone() {
        let crop = cropRect
        // Generate snapshot
        // We want to capture exactly what is inside the Crop Rect.
        // The ScrollView content is scaled and offset.
        
        // Create a renderer of size 1080x1080 (Canvas size)
        let outputSize = CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        
        let result = renderer.image { ctx in
            // Fill background white (or black?) - User app seems dark.
            // Let's use White for product cleanliness, or match view bg (Black).
            // Usually "Done" means "Save Item". Items on white look cleaner?
            // But if user sees black bars on screen, they expect black bars?
            // Let's stick to what they see -> Black (or transparent).
            // Making it Transparent is safest (PNG).
            
            // Map the Crop Rect (Screen Coords) to the Image View (Screen Coords transformed)
            // Actually, we can just draw the hierarchy?
            // Simpler: Snapshot the VIEW hierarchy inside the crop rect.
            
            // We need to draw 'imageView' into 'outputSize'.
            // Map: CropRect (Screen) -> OutputRect (0,0,1080,1080)
            
            // Calculate scale ratio
            let ratio = outputSize.width / crop.width
            
            // Transform Context:
            // 1. Scale by ratio (Screen -> Output)
            // 2. Translate by -crop.origin (Move crop start to 0,0)
            
            // BUT: We need to draw the IMAGE.
            // Image Frame in Screen Coords:
            // scrollView acts as window.
            // image frame = imageView.frame (relative to scrollview content) - contentOffset.
            // Wait, imageView.frame is in ScrollView Content Coordinates.
            // visibleRect = (contentOffset.x, contentOffset.y, bounds.width, bounds.height) [Approx]
            
            // Let's convert imageView frame to View (Screen) Coordinates
            let imgFrameInView = view.convert(imageView.frame, from: scrollView)
            
            // Now we have:
            // CropRect (Screen)
            // ImgRect (Screen)
            
            // We want to draw ImgRect into a Context that represents CropRect.
            // Relative position:
            let relativeFrame = imgFrameInView.offsetBy(dx: -crop.minX, dy: -crop.minY)
            
            // Scale up to Output
            let finalFrame = CGRect(
                x: relativeFrame.minX * ratio,
                y: relativeFrame.minY * ratio,
                width: relativeFrame.width * ratio,
                height: relativeFrame.height * ratio
            )
            
            // Draw image
            image.draw(in: finalFrame)
        }
        
        onSave(result)
    }
}

class CropperOverlayView: UIView {
    var cropRect: CGRect = .zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Dimmed background
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)
        
        // Clear hole
        context.setBlendMode(.clear)
        context.fill(cropRect)
        
        // Reset blend
        context.setBlendMode(.normal)
        
        // Stroke
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.0)
        context.stroke(cropRect)
        
        // Grid (3x3)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)
        
        let w = cropRect.width
        let h = cropRect.height
        let x = cropRect.minX
        let y = cropRect.minY
        
        // Verticals
        context.move(to: CGPoint(x: x + w/3, y: y))
        context.addLine(to: CGPoint(x: x + w/3, y: y + h))
        context.move(to: CGPoint(x: x + 2*w/3, y: y))
        context.addLine(to: CGPoint(x: x + 2*w/3, y: y + h))
        
        // Horizontals
        context.move(to: CGPoint(x: x, y: y + h/3))
        context.addLine(to: CGPoint(x: x + w, y: y + h/3))
        context.move(to: CGPoint(x: x, y: y + 2*h/3))
        context.addLine(to: CGPoint(x: x + w, y: y + 2*h/3))
        
        context.strokePath()
    }
}
