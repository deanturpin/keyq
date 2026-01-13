//
//  MusicNote.hpp
//  keyqExtension
//
//  Musical note representation and frequency conversion
//

#pragma once

#include <string>
#include <cmath>
#include <array>

struct MusicNote {
    float frequency;      // Frequency in Hz
    int midiNote;        // MIDI note number (0-127)
    int octave;          // Octave number
    int noteIndex;       // 0-11 (C, C#, D, D#, E, F, F#, G, G#, A, A#, B)
    float centsDeviation; // Deviation from perfect pitch in cents
    float magnitude;     // FFT magnitude in dB
    
    std::string noteName() const {
        static constexpr std::array<const char*, 12> noteNames = {
            "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
        };
        return std::string(noteNames[noteIndex]) + std::to_string(octave);
    }
    
    // Convert frequency to MIDI note number
    static float frequencyToMidi(float frequency, float referencePitch = 440.0f) {
        return 69.0f + 12.0f * std::log2(frequency / referencePitch);
    }
    
    // Convert MIDI note to frequency
    static float midiToFrequency(int midiNote, float referencePitch = 440.0f) {
        return referencePitch * std::pow(2.0f, (midiNote - 69) / 12.0f);
    }
    
    // Create MusicNote from frequency
    static MusicNote fromFrequency(float frequency, float magnitude, float referencePitch = 440.0f) {
        auto note = MusicNote{};
        note.frequency = frequency;
        note.magnitude = magnitude;
        
        // Calculate MIDI note (can be fractional)
        auto midiFloat = frequencyToMidi(frequency, referencePitch);
        note.midiNote = static_cast<int>(std::round(midiFloat));
        
        // Calculate cents deviation from perfect pitch
        note.centsDeviation = (midiFloat - note.midiNote) * 100.0f;
        
        // Extract octave and note index
        note.octave = note.midiNote / 12 - 1;  // MIDI note 0 = C-1
        note.noteIndex = note.midiNote % 12;
        
        return note;
    }
};

// Structure to hold detected peaks
struct DetectedPeak {
    size_t binIndex;
    float frequency;
    float magnitude;
    MusicNote note;
};
