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

    // Tunable parameters - optimised defaults from testing
    @State private var smoothingFactor: Float = 0.5         // Max: smoothest response
    @State private var persistenceThreshold: Float = -60.0
    @State private var maxPersistenceFrames: Float = 180.0  // Max: longest glow
    @State private var minPersistenceFrames: Float = 3.0
    @State private var binRampUp: Float = 0.5
    @State private var binDecay: Float = 1.0                // Min: slowest fade
    @State private var noteDecay: Float = 2.8
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

            // Toggle button - always visible
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: showControls ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10))
                    Text(showControls ? "Hide Controls" : "Show Controls")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.2))
            }
            .buttonStyle(.plain)

            // Control panel with rotary knobs (hidden by default)
            if showControls {
                HStack(spacing: 12) {
                    RotaryKnob(
                        label: "Smoothing",
                        value: $smoothingFactor,
                        range: 0.0...0.5,
                        valueFormatter: { String(format: "%.2f", $0) }
                    )

                    RotaryKnob(
                        label: "Brightness\nTime",
                        value: $maxPersistenceFrames,
                        range: 30.0...180.0,
                        valueFormatter: { String(format: "%.0f", $0) }
                    )

                    RotaryKnob(
                        label: "Ramp-Up",
                        value: $binRampUp,
                        range: 0.5...5.0,
                        valueFormatter: { String(format: "%.1f", $0) }
                    )

                    RotaryKnob(
                        label: "Decay",
                        value: $binDecay,
                        range: 1.0...10.0,
                        valueFormatter: { String(format: "%.1f", $0) }
                    )

                    RotaryKnob(
                        label: "Note Min",
                        value: $minPersistenceFrames,
                        range: 3.0...60.0,
                        valueFormatter: { String(format: "%.0f", $0) }
                    )

                    RotaryKnob(
                        label: "Note\nDecay",
                        value: $noteDecay,
                        range: 0.5...5.0,
                        valueFormatter: { String(format: "%.1f", $0) }
                    )

                    RotaryKnob(
                        label: "Threshold",
                        value: $persistenceThreshold,
                        range: (-80.0)...(-40.0),
                        valueFormatter: { String(format: "%.0fdB", $0) }
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.3))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 800, idealWidth: 1400, maxWidth: .infinity,
               minHeight: 200, idealHeight: showControls ? 380 : 280, maxHeight: .infinity)
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
