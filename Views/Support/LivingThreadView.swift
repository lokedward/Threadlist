// LivingThreadView.swift
// Dynamic logo-based animation for the Studio

import SwiftUI

struct LivingThreadView: View {
    var isGenerating: Bool = false
    
    var body: some View {
        ZStack {
            // Draw multiple "threads" that write the logo out of sync for depth
            ForEach(0..<3) { i in
                AnimatedLogoTView(
                    color: i == 0 ? PoshTheme.Colors.gold : PoshTheme.Colors.ink,
                    lineWidth: i == 0 ? 3.0 : 1.5,
                    opacity: i == 0 ? 0.3 : 0.1,
                    delay: Double(i) * 0.4,
                    speedMultiplier: isGenerating ? 1.5 : 1.0
                )
                .offset(x: CGFloat(i * 4), y: CGFloat(i * 2))
                .blur(radius: i == 0 ? 0 : 0.5)
            }
        }
    }
}

struct ThreadditLogoT: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        
        // Scale and center the coordinates
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (x / 100) * w, y: rect.minY + (y / 100) * h)
        }
        
        // --- 1. The Starting Curl & Top Flourish ---
        // Start with a tighter curl on the left
        path.move(to: p(25, 45))
        
        // Initial curl up
        path.addCurve(
            to: p(20, 30),
            control1: p(15, 45),
            control2: p(15, 35)
        )
        
        // Sweep across the top
        path.addCurve(
            to: p(55, 20),
            control1: p(30, 20),
            control2: p(45, 18)
        )
        
        // The right "Needle Eye" loop
        path.addCurve(
            to: p(85, 30),
            control1: p(70, 22),
            control2: p(80, 20)
        )
        
        path.addCurve(
            to: p(72, 42),
            control1: p(92, 40),
            control2: p(85, 48)
        )
        
        // 2. The Integrated Vertical Downstroke (One continuous movement feeling)
        path.addCurve(
            to: p(52, 30),
            control1: p(65, 38),
            control2: p(60, 32)
        )
        
        // The main body - smoother "S" curve
        path.addCurve(
            to: p(48, 80),
            control1: p(45, 35),
            control2: p(65, 65)
        )
        
        // 3. The Graceful Tail Loop
        path.addCurve(
            to: p(30, 75),
            control1: p(40, 95),
            control2: p(25, 90)
        )
        
        path.addCurve(
            to: p(35, 68),
            control1: p(35, 65),
            control2: p(40, 65)
        )
        
        return path
    }
}

struct AnimatedLogoTView: View {
    @State private var writingProgress: CGFloat = 0
    let color: Color
    let lineWidth: CGFloat
    let opacity: Double
    let delay: Double
    let speedMultiplier: Double
    
    var body: some View {
        ThreadditLogoT()
            .trim(from: 0, to: writingProgress)
            .stroke(
                color.opacity(opacity),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 2.5 / speedMultiplier)
                        .delay(delay)
                        .repeatForever(autoreverses: true)
                ) {
                    writingProgress = 1.0
                }
            }
    }
}

#Preview {
    ZStack {
        PoshTheme.Colors.canvas.ignoresSafeArea()
        LivingThreadView(isGenerating: true)
            .frame(width: 300, height: 300)
    }
}
