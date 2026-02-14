// LivingThreadView.swift
// Minimalist "Digital Knit" weaving for the Studio

import SwiftUI

struct LivingThreadView: View {
    var isGenerating: Bool = false
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let cycleDuration: Double = isGenerating ? 3.0 : 5.0
                let progress = (time.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration
                
                // We define 3 stages: 
                // 0.0 - 0.6: Vertical lines trace down
                // 0.6 - 0.9: Horizontal "shuttle" sweeps across
                // 0.9 - 1.0: Fade out
                
                let verticalCount = 8
                let horizontalY = size.height * 0.5
                
                // 1. Draw Vertical "Warp" Threads
                for i in 0..<verticalCount {
                    let xPos = size.width * (0.2 + Double(i) * 0.08)
                    let startDelay = Double(i) * 0.05
                    let verticalProgress = min(1.0, max(0.0, (progress - startDelay) / 0.4))
                    
                    if verticalProgress > 0 {
                        var path = Path()
                        path.move(to: CGPoint(x: xPos, y: 0))
                        path.addLine(to: CGPoint(x: xPos, y: size.height * verticalProgress))
                        
                        let opacity = progress > 0.9 ? (1.0 - (progress - 0.9) * 10) : 0.15
                        context.stroke(
                            path,
                            with: .color(PoshTheme.Colors.ink.opacity(opacity)),
                            style: StrokeStyle(lineWidth: 0.5)
                        )
                        
                        // Add a small "needle" or "bead" at the leading edge
                        if progress < 0.9 {
                            let bead = Path(ellipseIn: CGRect(x: xPos - 1, y: (size.height * verticalProgress) - 1, width: 2, height: 2))
                            context.fill(bead, with: .color(PoshTheme.Colors.gold.opacity(0.4)))
                        }
                    }
                }
                
                // 2. Draw Horizontal "Weft" Thread (The Shuttle)
                let horizontalProgress = min(1.0, max(0.0, (progress - 0.5) / 0.4))
                if horizontalProgress > 0 {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: horizontalY))
                    path.addLine(to: CGPoint(x: size.width * horizontalProgress, y: horizontalY))
                    
                    let opacity = progress > 0.9 ? (1.0 - (progress - 0.9) * 10) : 0.2
                    context.stroke(
                        path,
                        with: .color(PoshTheme.Colors.gold.opacity(opacity)),
                        style: StrokeStyle(lineWidth: 1.0)
                    )
                    
                    // Interaction glow at intersection points
                    for i in 0..<verticalCount {
                        let xPos = size.width * (0.2 + Double(i) * 0.08)
                        if size.width * horizontalProgress > xPos {
                            let dot = Path(ellipseIn: CGRect(x: xPos - 2, y: horizontalY - 2, width: 4, height: 4))
                            context.fill(dot, with: .color(PoshTheme.Colors.gold.opacity(0.3)))
                        }
                    }
                }
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
