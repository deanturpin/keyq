//
//  keyqExtensionMainView.swift
//  keyqExtension
//
//  Created by Dean Turpin on 12/01/2026.
//

import SwiftUI

struct keyqExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup
    var audioUnit: keyqExtensionAudioUnit
    
    @State private var fftMagnitudes: [Float] = []
    @State private var smoothedMagnitudes: [Float] = []
    @State private var binPersistence: [Float] = []  // Track how long each bin has been active
    @State private var sampleRate: Float = 44100.0
    @State private var fftSize: UInt32 = 2048
    @State private var detectedPeaks: [keyqExtensionAudioUnit.DetectedPeak] = []
    @State private var persistentPeaks: [String: (peak: keyqExtensionAudioUnit.DetectedPeak, frames: Int)] = [:]
    @State private var timer: Timer?

    // Tunable parameters
    @State private var smoothingFactor: Float = 0.15
    @State private var persistenceThreshold: Float = -60.0
    @State private var maxPersistenceFrames: Float = 60.0
    @State private var minPersistenceFrames: Float = 18.0
    @State private var binRampUp: Float = 2.0
    @State private var binDecay: Float = 4.0
    @State private var noteDecay: Float = 1.0
    @State private var showControls: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // FFT Visualisation - only show peaks that have sustained for minimum duration
            let sustainedPeaks = persistentPeaks.values
                .filter { $0.frames >= Int(minPersistenceFrames) }
                .map { $0.peak }

            FFTView(magnitudes: smoothedMagnitudes, binPersistence: binPersistence, sampleRate: sampleRate, fftSize: fftSize, peaks: Array(sustainedPeaks))
                .padding(.horizontal, 8)
                .padding(.vertical, 8)

            // Control panel toggle and sliders
            if showControls {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Group {
                            Text("FFT Smoothing").font(.caption).foregroundColor(.white.opacity(0.7))
                            HStack {
                                Text("0").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Slider(value: $smoothingFactor, in: 0.0...0.5)
                                Text("0.5").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.2f", smoothingFactor)).font(.caption2).foregroundColor(.yellow).frame(width: 35)
                            }
                        }

                        Group {
                            Text("Brightness Time (frames)").font(.caption).foregroundColor(.white.opacity(0.7))
                            HStack {
                                Text("30").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Slider(value: $maxPersistenceFrames, in: 30.0...180.0)
                                Text("180").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.0f", maxPersistenceFrames)).font(.caption2).foregroundColor(.yellow).frame(width: 35)
                            }
                        }

                        Group {
                            Text("Brightness Ramp-Up").font(.caption).foregroundColor(.white.opacity(0.7))
                            HStack {
                                Text("0.5").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Slider(value: $binRampUp, in: 0.5...5.0)
                                Text("5").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.1f", binRampUp)).font(.caption2).foregroundColor(.yellow).frame(width: 35)
                            }
                        }

                        Group {
                            Text("Brightness Decay").font(.caption).foregroundColor(.white.opacity(0.7))
                            HStack {
                                Text("1").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Slider(value: $binDecay, in: 1.0...10.0)
                                Text("10").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.1f", binDecay)).font(.caption2).foregroundColor(.yellow).frame(width: 35)
                            }
                        }

                        Group {
                            Text("Note Min Frames").font(.caption).foregroundColor(.white.opacity(0.7))
                            HStack {
                                Text("3").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Slider(value: $minPersistenceFrames, in: 3.0...60.0)
                                Text("60").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.0f", minPersistenceFrames)).font(.caption2).foregroundColor(.yellow).frame(width: 35)
                            }
                        }

                        Group {
                            Text("Note Decay").font(.caption).foregroundColor(.white.opacity(0.7))
                            HStack {
                                Text("0.5").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Slider(value: $noteDecay, in: 0.5...5.0)
                                Text("5").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.1f", noteDecay)).font(.caption2).foregroundColor(.yellow).frame(width: 35)
                            }
                        }

                        Group {
                            Text("Persistence Threshold (dB)").font(.caption).foregroundColor(.white.opacity(0.7))
                            HStack {
                                Text("-80").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Slider(value: $persistenceThreshold, in: (-80.0)...(-40.0))
                                Text("-40").font(.caption2).foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.0f", persistenceThreshold)).font(.caption2).foregroundColor(.yellow).frame(width: 35)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.3))
            }

            // Toggle button
            Button(action: { showControls.toggle() }) {
                HStack {
                    Image(systemName: showControls ? "chevron.down" : "chevron.up")
                    Text(showControls ? "Hide Controls" : "Show Controls")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .background(Color.black.opacity(0.2))
        }
        .frame(minWidth: 1200, idealWidth: 1400, maxWidth: .infinity, minHeight: 260, idealHeight: showControls ? 540 : 280, maxHeight: showControls ? 600 : 320)
        .background(Color(white: 0.15))
        .onAppear {
            startFFTUpdates()
        }
        .onDisappear {
            stopFFTUpdates()
        }
    }
    
    private func startFFTUpdates() {
        // Update FFT display at 60 FPS for tight response
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateFFTData()
        }
    }
    
    private func stopFFTUpdates() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateFFTData() {
        let newMagnitudes = audioUnit.getFFTMagnitudes()
        let newPeaks = audioUnit.getDetectedPeaks()

        fftMagnitudes = newMagnitudes
        sampleRate = audioUnit.getSampleRate()
        fftSize = audioUnit.getFFTSize()
        detectedPeaks = newPeaks

        // Apply exponential smoothing to reduce jumpiness and create graceful fade-out
        if smoothedMagnitudes.isEmpty {
            smoothedMagnitudes = fftMagnitudes
        } else if fftMagnitudes.count == smoothedMagnitudes.count {
            for i in 0..<fftMagnitudes.count {
                smoothedMagnitudes[i] = smoothingFactor * smoothedMagnitudes[i] + (1.0 - smoothingFactor) * fftMagnitudes[i]
            }
        } else {
            smoothedMagnitudes = fftMagnitudes
        }

        // Initialize bin persistence array if needed
        if binPersistence.count != fftMagnitudes.count {
            binPersistence = Array(repeating: 0.0, count: fftMagnitudes.count)
        }

        // Update bin persistence - bins get brighter the longer they sustain
        for i in 0..<fftMagnitudes.count {
            if smoothedMagnitudes[i] > persistenceThreshold {
                // Bin is active - increment persistence up to max
                binPersistence[i] = min(binPersistence[i] + binRampUp, maxPersistenceFrames)
            } else {
                // Bin is quiet - decay persistence quickly
                binPersistence[i] = max(binPersistence[i] - binDecay, 0.0)
            }
        }

        // No moving average - use raw bins for maximum detail and sharpest response

        // Update peak persistence tracking - peaks fade out naturally when audio stops
        updatePersistentPeaks()
    }

    private func updatePersistentPeaks() {
        var currentPeakNotes = Set<String>()

        // Process incoming peaks - update or create tracking entries
        for peak in detectedPeaks {
            let noteKey = peak.noteName

            if var existing = persistentPeaks[noteKey] {
                // Peak still present - increment frame count and update peak data
                existing.frames += 1
                existing.peak = peak
                persistentPeaks[noteKey] = existing
            } else {
                // New peak - start tracking
                persistentPeaks[noteKey] = (peak: peak, frames: 1)
            }

            currentPeakNotes.insert(noteKey)
        }

        // Handle peaks that disappeared this frame
        for (noteKey, var value) in persistentPeaks where !currentPeakNotes.contains(noteKey) {
            // Decay frame count for missing peaks
            value.frames = max(0, value.frames - Int(noteDecay))

            if value.frames == 0 {
                persistentPeaks.removeValue(forKey: noteKey)
            } else {
                persistentPeaks[noteKey] = value
            }
        }
    }
}
