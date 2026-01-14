//
//  RotaryKnob.swift
//  keyqExtension
//
//  Created by Dean Turpin on 13/01/2026.
//

import SwiftUI

struct RotaryKnob: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let valueFormatter: (Float) -> String

    @State private var isDragging = false
    @State private var lastDragY: CGFloat = 0

    private let knobSize: CGFloat = 50
    private let lineWidth: CGFloat = 3

    private var normalizedValue: Double {
        Double((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private var rotationAngle: Angle {
        // Map 0-1 to -135° to +135° (270° total range)
        let degrees = -135.0 + (normalizedValue * 270.0)
        return .degrees(degrees)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Rotary knob - entire circle is draggable
            ZStack {
                // Invisible hit area (full circle)
                Circle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: knobSize + 10, height: knobSize + 10)

                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: lineWidth)
                    .frame(width: knobSize, height: knobSize)

                // Value arc
                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(
                        Color(red: 0.3, green: 0.5, blue: 1.0),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: knobSize, height: knobSize)
                    .rotationEffect(.degrees(-90)) // Start from top

                // Center dot indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .offset(y: -(knobSize / 2 - lineWidth - 3))
                    .rotationEffect(rotationAngle)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            lastDragY = gesture.location.y
                        }

                        let delta = lastDragY - gesture.location.y
                        lastDragY = gesture.location.y

                        // Sensitivity: 100 pixels = full range
                        let sensitivity = (range.upperBound - range.lowerBound) / 100.0
                        let newValue = value + Float(delta) * sensitivity
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            // Label
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(width: 70)

            // Value display
            Text(valueFormatter(value))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.yellow)
        }
    }
}
