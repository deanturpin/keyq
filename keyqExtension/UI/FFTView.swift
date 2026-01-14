//
//  FFTView.swift
//  keyqExtension
//
//  FFT spectrum visualisation with logarithmic X-axis for musical analysis
//

import SwiftUI

struct FFTView: View {
    let magnitudes: [Float]
    let binPersistence: [Float]
    let sampleRate: Float
    let fftSize: UInt32
    let peaks: [keyqExtensionAudioUnit.DetectedPeak]

    var body: some View {
        VStack(spacing: 0) {
            // FFT spectrum display with overlay
            ZStack {
                GeometryReader { geometry in
                    Canvas { context, size in
                        drawFFT(context: context, size: size)
                    }
                }

                VStack {
                    Spacer()

                    // Translucent yellow banner with project name
                    Text("keyq")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.15))

                    Spacer()

                    // Git hash in bottom right corner
                    HStack {
                        Spacer()
                        Text(GitHash.hash)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.trailing, 8)
                            .padding(.bottom, 4)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            // Dedicated note display bar
            Canvas { context, size in
                drawNotesBar(context: context, size: size)
            }
            .frame(height: 40)
        }
        .background(Color(red: 0.1, green: 0.12, blue: 0.18))  // Dark navy like idapp.io
        .cornerRadius(12)
    }
    
    private func drawFFT(context: GraphicsContext, size: CGSize) {
        guard !magnitudes.isEmpty else { return }

        let width = size.width
        let height = size.height
        let topMargin: CGFloat = 8  // Internal top margin for bars
        let bottomMargin: CGFloat = 15  // Space for frequency labels
        let drawHeight = height - topMargin - bottomMargin

        // Display all FFT bins directly (FFT size / 2)
        let numBins = magnitudes.count

        // dB range: -80 dB to +10 dB (headroom for peaks)
        let minDB: Float = -80.0
        let maxDB: Float = 10.0

        // Calculate frequency range to display (20 Hz to 16384 Hz)
        let minFreq: Float = 20.0
        let maxFreq: Float = 16384.0  // 2^14, closest power of 2 to 16 kHz

        // Logarithmic frequency spacing for musical analysis
        let logMinFreq = log10(minFreq)
        let logMaxFreq = log10(maxFreq)

        // Draw bars with logarithmic X-axis spacing
        let numDisplayBars = Int(width / 2.0)  // Aim for 2 pixels per bar

        for i in 0..<numDisplayBars {
            // Calculate frequency for this X position using log scale
            let t = Float(i) / Float(numDisplayBars - 1)
            let logFreq = logMinFreq + t * (logMaxFreq - logMinFreq)
            let freq = pow(10.0, logFreq)

            // Find corresponding FFT bin
            let bin = Int((freq / sampleRate) * Float(fftSize))
            guard bin >= 0 && bin < numBins else { continue }

            let db = magnitudes[bin]

            // Map dB to bar height
            let normalizedMagnitude = (db - minDB) / (maxDB - minDB)
            let clampedMagnitude = max(0.0, min(1.0, normalizedMagnitude))
            let barHeight = CGFloat(clampedMagnitude) * drawHeight

            // Calculate brightness based on bin persistence (0.0 to 1.0)
            let persistenceStrength = bin < binPersistence.count ? min(binPersistence[bin] / 60.0, 1.0) : 0.0

            // Base brightness increases with persistence (0.3 to 1.0 range)
            let brightness = Double(0.3 + (persistenceStrength * 0.7))

            let x = CGFloat(i) * (width / CGFloat(numDisplayBars))
            let barWidth = width / CGFloat(numDisplayBars)
            let barRect = CGRect(
                x: x,
                y: topMargin + (drawHeight - barHeight),
                width: barWidth,
                height: barHeight
            )

            // Create gradient with brightness modulated by persistence
            // Gradient strength proportional to bar height - short bars stay closer to background
            let topColor = Color(red: 0.3 * brightness, green: 0.5 * brightness, blue: 1.0 * brightness)
            let backgroundColor = Color(red: 0.1, green: 0.12, blue: 0.18)

            // For short bars, interpolate towards background colour
            let heightRatio = Double(clampedMagnitude)  // 0.0 to 1.0
            let midColor = Color(
                red: 0.1 + (0.3 * brightness - 0.1) * heightRatio * 0.5,
                green: 0.12 + (0.5 * brightness - 0.12) * heightRatio * 0.5,
                blue: 0.18 + (1.0 * brightness - 0.18) * heightRatio * 0.5
            )

            let gradient = Gradient(colors: [topColor, midColor, backgroundColor])
            context.fill(
                Path(barRect),
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: barRect.midX, y: barRect.minY),
                    endPoint: CGPoint(x: barRect.midX, y: barRect.maxY)
                )
            )
        }

        // Draw frequency markers at bottom
        drawFrequencyMarkers(context: context, size: size, width: width, bottomY: height - 2, minFreq: minFreq, maxFreq: maxFreq)
    }

    private func drawFrequencyMarkers(context: GraphicsContext, size: CGSize, width: CGFloat, bottomY: CGFloat, minFreq: Float, maxFreq: Float) {
        // Draw frequency markers at key frequencies
        let markerFrequencies: [Float] = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 16000]

        // Logarithmic scale constants
        let logMinFreq = log10(minFreq)
        let logMaxFreq = log10(maxFreq)

        for freq in markerFrequencies {
            guard freq >= minFreq && freq <= maxFreq else { continue }

            // Calculate X position using logarithmic spacing
            let logFreq = log10(freq)
            let t = (logFreq - logMinFreq) / (logMaxFreq - logMinFreq)
            let x = CGFloat(t) * width

            // Draw small tick mark
            var path = Path()
            path.move(to: CGPoint(x: x, y: bottomY - 8))
            path.addLine(to: CGPoint(x: x, y: bottomY))

            context.stroke(
                path,
                with: .color(.white.opacity(0.3)),
                lineWidth: 1
            )

            // Format frequency label
            let label = freq >= 1000 ? "\(Int(freq / 1000))k" : "\(Int(freq))"

            // Draw label
            context.draw(
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.5)),
                at: CGPoint(x: x, y: bottomY - 10),
                anchor: .bottom
            )
        }
    }

    private func drawNotesBar(context: GraphicsContext, size: CGSize) {
        guard !peaks.isEmpty else { return }

        let width = size.width
        let height = size.height

        // Draw subtle divider line at top
        var dividerPath = Path()
        dividerPath.move(to: CGPoint(x: 0, y: 0))
        dividerPath.addLine(to: CGPoint(x: width, y: 0))
        context.stroke(
            dividerPath,
            with: .color(.white.opacity(0.1)),
            lineWidth: 1
        )

        // Logarithmic frequency range matching the FFT display
        let minFreq: Float = 20.0
        let maxFreq: Float = 16384.0

        // Logarithmic scale constants
        let logMinFreq = log10(minFreq)
        let logMaxFreq = log10(maxFreq)

        // Find magnitude range for opacity scaling
        let magnitudes = peaks.map { $0.magnitude }
        let maxMagnitude = magnitudes.max() ?? 0.0
        let minMagnitude = magnitudes.min() ?? -80.0
        let magnitudeRange = maxMagnitude - minMagnitude

        for peak in peaks {
            // Skip peaks outside visible range
            guard peak.frequency >= minFreq && peak.frequency <= maxFreq else { continue }

            // Calculate X position using logarithmic spacing
            let logFreq = log10(peak.frequency)
            let t = (logFreq - logMinFreq) / (logMaxFreq - logMinFreq)
            let x = CGFloat(t) * width

            // Calculate opacity based on magnitude (0.3 to 1.0 range)
            let magnitudeStrength = magnitudeRange > 0 ? (peak.magnitude - minMagnitude) / magnitudeRange : 1.0
            let opacity = Double(0.3 + (magnitudeStrength * 0.7))

            // Draw subtle vertical guide line with magnitude-based opacity
            var markerPath = Path()
            markerPath.move(to: CGPoint(x: x, y: 0))
            markerPath.addLine(to: CGPoint(x: x, y: height))

            context.stroke(
                markerPath,
                with: .color(.yellow.opacity(opacity * 0.2)),
                style: StrokeStyle(lineWidth: 1, dash: [2, 4])
            )

            // Draw note label with magnitude-based opacity
            context.draw(
                Text("\(peak.noteName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.yellow.opacity(opacity)),
                at: CGPoint(x: x, y: height / 2),
                anchor: .center
            )
        }
    }
}
