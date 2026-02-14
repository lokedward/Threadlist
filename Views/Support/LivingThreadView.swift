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

struct ThreadditLogoTBar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (x / 100) * w, y: rect.minY + (y / 100) * h)
        }
        
        // --- Stroke 1: The Top Bar ---
        path.move(to: p(18, 42))
        
        // Initial curl up
        path.addCurve(
            to: p(22, 28),
            control1: p(12, 40),
            control2: p(12, 30)
        )
        
        // Sweep across the top
        path.addCurve(
            to: p(55, 20),
            control1: p(32, 20),
            control2: p(45, 18)
        )
        
        // The right loop - explicitly closing back onto the main line
        path.addCurve(
            to: p(88, 28),
            control1: p(75, 22),
            control2: p(85, 20)
        )
        // Closing the circle loop
        path.addCurve(
            to: p(75, 42),
            control1: p(95, 35),
            control2: p(90, 48)
        )
        path.addCurve(
            to: p(75, 24), // Connects back near the top bar intersection
            control1: p(65, 38),
            control2: p(65, 28)
        )
        
        return path
    }
}

struct ThreadditLogoTBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (x / 100) * w, y: rect.minY + (y / 100) * h)
        }
        
        // --- Stroke 2: Clean slanted vertical body ---
        path.move(to: p(58, 22))
        
        // A clean, slightly slanted downstroke
        path.addLine(to: p(45, 80))
        
        // Graceful bottom tail loop (Cursive finish)
        path.addCurve(
            to: p(25, 75),
            control1: p(40, 95),
            control2: p(20, 90)
        )
        path.addCurve(
            to: p(35, 65),
            control1: p(28, 65),
            control2: p(32, 63)
        )
        
        return path
    }
}

struct AnimatedLogoTView: View {
    @State private var barProgress: CGFloat = 0
    @State private var bodyProgress: CGFloat = 0
    
    let color: Color
    let lineWidth: CGFloat
    let opacity: Double
    let delay: Double
    let speedMultiplier: Double
    
    var body: some View {
        ZStack {
            // Stroke 1: The Top Bar
            ThreadditLogoTBar()
                .trim(from: 0, to: barProgress)
                .stroke(
                    color.opacity(opacity),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            
            // Stroke 2: The Body
            ThreadditLogoTBody()
                .trim(from: 0, to: bodyProgress)
                .stroke(
                    color.opacity(opacity),
                    style: StrokeStyle(lineWidth: lineWidth * 1.1, lineCap: .round, lineJoin: .round)
                )
        }
        .onAppear {
            let duration = 2.0 / speedMultiplier
            
            // Sequence the animations
            withAnimation(
                Animation.easeInOut(duration: duration * 0.5)
                    .delay(delay)
                    .repeatForever(autoreverses: true)
            ) {
                barProgress = 1.0
            }
            
            withAnimation(
                Animation.easeInOut(duration: duration * 0.5)
                    .delay(delay + (duration * 0.3)) // Start body slightly after bar starts
                    .repeatForever(autoreverses: true)
            ) {
                bodyProgress = 1.0
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
