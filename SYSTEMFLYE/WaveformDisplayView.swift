import SwiftUI

struct WaveformDisplayView: View {
    let waveformData: [Float]
    
    var body: some View {
        Canvas { context, size in
            // Background gradient
            let gradient = Gradient(colors: [
                    Color(red: 0.08, green: 0.2, blue: 0.3),
                    Color(red: 0.05, green: 0.15, blue: 0.25)
            ])
            
            context.fill(
                Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12),
                with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height))
            )
            
            // Draw waveform
            if !waveformData.isEmpty {
                var path = Path()
                let width = size.width
                let height = size.height
                let centerY = height / 2
                let stepX = width / CGFloat(waveformData.count)
                
                // Draw top waveform
                path.move(to: CGPoint(x: 0, y: centerY))
                
                for (index, amplitude) in waveformData.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = centerY - (CGFloat(amplitude) * (height / 2 - 10))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                // Close path and draw
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.3, green: 0.8, blue: 1.0),
                            Color(red: 0.2, green: 0.6, blue: 0.9)
                        ]),
                        startPoint: CGPoint(x: 0, y: centerY),
                        endPoint: CGPoint(x: width, y: centerY)
                    ),
                    lineWidth: 1.5
                )
                
                // Draw bottom waveform (mirror)
                var bottomPath = Path()
                bottomPath.move(to: CGPoint(x: 0, y: centerY))
                
                for (index, amplitude) in waveformData.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = centerY + (CGFloat(amplitude) * (height / 2 - 10))
                    
                    if index == 0 {
                        bottomPath.move(to: CGPoint(x: x, y: y))
                    } else {
                        bottomPath.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                context.stroke(
                    bottomPath,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.3, green: 0.8, blue: 1.0),
                            Color(red: 0.2, green: 0.6, blue: 0.9)
                        ]),
                        startPoint: CGPoint(x: 0, y: centerY),
                        endPoint: CGPoint(x: width, y: centerY)
                    ),
                    lineWidth: 1.5
                )
            }
            
            // Center line
            let centerPath = Path(
                CGRect(
                    x: 0,
                    y: size.height / 2 - 0.5,
                    width: size.width,
                    height: 1
                )
            )
            
            context.stroke(
                centerPath,
                with: .color(Color.white.opacity(0.1)),
                lineWidth: 0.5
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.18))
        )
    }
}

struct FrequencySpectrumView: View {
    let frequencyData: [Float]
    
    var body: some View {
        Canvas { context, size in
            let gradient = Gradient(colors: [
                    Color(red: 0.08, green: 0.2, blue: 0.3),
                    Color(red: 0.05, green: 0.15, blue: 0.25)
            ])
            
            context.fill(
                Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12),
                with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height))
            )
            
            let barWidth = size.width / CGFloat(frequencyData.count)
            let maxHeight = size.height - 20
            
            for (index, magnitude) in frequencyData.enumerated() {
                let barHeight = CGFloat(magnitude) * maxHeight
                let x = CGFloat(index) * barWidth
                let y = size.height - barHeight - 10
                
                // Create gradient for each bar
                let barGradient = Gradient(colors: [
                        Color(
                            red: 0.2 + CGFloat(index) / CGFloat(frequencyData.count) * 0.8,
                            green: 0.6,
                            blue: 1.0 - CGFloat(index) / CGFloat(frequencyData.count) * 0.5
                        ),
                        Color(
                            red: 0.1 + CGFloat(index) / CGFloat(frequencyData.count) * 0.6,
                            green: 0.4,
                            blue: 0.8
                        )
                    ])
                
                let barRect = RoundedRectangle(
                    cornerRadius: 2,
                    style: .continuous
                )
                
                context.fill(
                    barRect.path(
                        in: CGRect(
                            x: x + 1,
                            y: y,
                            width: barWidth - 2,
                            height: barHeight
                        )
                    ),
                    with: .linearGradient(
                        barGradient,
                        startPoint: CGPoint(x: x, y: size.height),
                        endPoint: CGPoint(x: x, y: y)
                    )
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.18))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformDisplayView(
            waveformData: (0..<256).map { i in
                Float(sin(Double(i) * 0.1)) * 0.5 + 0.3
            }
        )
        .frame(height: 150)
        
        FrequencySpectrumView(
            frequencyData: (0..<64).map { i in
                Float(sin(Double(i) * 0.2)) * 0.5 + 0.3
            }
        )
        .frame(height: 150)
    }
    .padding()
    .background(Color(red: 0.08, green: 0.08, blue: 0.12))
}
