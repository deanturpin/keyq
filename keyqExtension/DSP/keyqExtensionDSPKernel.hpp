//
//  keyqExtensionDSPKernel.hpp
//  keyqExtension
//
//  Created by Dean Turpin on 12/01/2026.
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import <algorithm>
#import <vector>
#import <span>
#import <cmath>

#import "keyqExtensionParameterAddresses.h"
#import "MusicNote.hpp"

// keyqExtensionDSPKernel
// As a non-ObjC class, this is safe to use from render thread.
class keyqExtensionDSPKernel {
public:
    void initialize(int inputChannelCount, int outputChannelCount, double inSampleRate) {
        mSampleRate = inSampleRate;
        setupFFT();
    }
    
    void deInitialize() {
        teardownFFT();
    }
    
    // MARK: - Bypass
    bool isBypassed() {
        return mBypassed;
    }
    
    void setBypass(bool shouldBypass) {
        mBypassed = shouldBypass;
    }
    
    // MARK: - Parameter Getter / Setter
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case keyqExtensionParameterAddress::gain:
                mGain = value;
                break;
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        switch (address) {
            case keyqExtensionParameterAddress::gain:
                return static_cast<AUValue>(mGain);
            default:
                return 0.f;
        }
    }
    
    // MARK: - Max Frames
    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }
    
    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }
    
    // MARK: - Musical Context
    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }
    
    // MARK: - FFT Access (Swift-callable)
    UInt32 getFFTMagnitudesCount() const {
        return static_cast<UInt32>(mFFTMagnitudes.size());
    }
    
    float getFFTMagnitude(UInt32 index) const {
        if (index < mFFTMagnitudes.size())
            return mFFTMagnitudes[index];
        return 0.0f;
    }
    
    float getSampleRate() const {
        return static_cast<float>(mSampleRate);
    }
    
    UInt32 getFFTSize() const {
        return kFFTSize;
    }
    
    // MARK: - Peak Detection Access
    UInt32 getPeakCount() const {
        return static_cast<UInt32>(mDetectedPeaks.size());
    }
    
    float getPeakFrequency(UInt32 index) const {
        if (index < mDetectedPeaks.size())
            return mDetectedPeaks[index].frequency;
        return 0.0f;
    }
    
    float getPeakMagnitude(UInt32 index) const {
        if (index < mDetectedPeaks.size())
            return mDetectedPeaks[index].magnitude;
        return 0.0f;
    }
    
    int getPeakMidiNote(UInt32 index) const {
        if (index < mDetectedPeaks.size())
            return mDetectedPeaks[index].note.midiNote;
        return 0;
    }
    
    int getPeakNoteIndex(UInt32 index) const {
        if (index < mDetectedPeaks.size())
            return mDetectedPeaks[index].note.noteIndex;
        return 0;
    }
    
    int getPeakOctave(UInt32 index) const {
        if (index < mDetectedPeaks.size())
            return mDetectedPeaks[index].note.octave;
        return 0;
    }
    
    float getPeakCents(UInt32 index) const {
        if (index < mDetectedPeaks.size())
            return mDetectedPeaks[index].note.centsDeviation;
        return 0.0f;
    }
    
    // MARK: - Internal Process
    void process(std::span<float const*> inputBuffers, std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        assert(inputBuffers.size() == outputBuffers.size());
        
        if (mBypassed) {
            for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel)
                std::copy_n(inputBuffers[channel], frameCount, outputBuffers[channel]);
            return;
        }
        
        // Process audio with gain and collect samples for FFT (use first channel)
        for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            // Write to circular buffer for FFT analysis
            mCircularBuffer[mCircularBufferWriteIndex] = inputBuffers[0][frameIndex];
            mCircularBufferWriteIndex = (mCircularBufferWriteIndex + 1) % kFFTSize;
            
            // Apply gain to all channels
            for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel)
                outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex] * static_cast<float>(mGain);
        }
        
        // Perform FFT periodically (every kFFTSize / 8 samples for tighter response)
        mFramesSinceLastFFT += frameCount;
        if (mFramesSinceLastFFT >= kFFTSize / 8) {
            mFramesSinceLastFFT = 0;
            performFFT();
            detectPeaks();
        }
    }
    
    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
            case AURenderEventParameter:
                handleParameterEvent(now, event->parameter);
                break;
            default:
                break;
        }
    }
    
    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        setParameter(parameterEvent.parameterAddress, parameterEvent.value);
    }
    
private:
    static constexpr size_t kFFTSize = 4096;  // High resolution for precise frequency analysis
    static constexpr size_t kFFTSizeOver2 = kFFTSize / 2;
    static constexpr float kPeakThresholdDB = -30.0f;  // Minimum peak magnitude (stricter)
    static constexpr size_t kMaxPeaks = 10;  // Maximum peaks to detect (reduced)
    static constexpr float kReferencePitch = 440.0f;  // A4 = 440 Hz
    
    // MARK: - FFT Setup
    void setupFFT() {
        mLog2N = static_cast<vDSP_Length>(std::log2(kFFTSize));
        mFFTSetup = vDSP_create_fftsetup(mLog2N, FFT_RADIX2);

        mCircularBuffer.resize(kFFTSize, 0.0f);
        mFFTInputBuffer.resize(kFFTSize, 0.0f);
        mWindow.resize(kFFTSize);
        mFFTMagnitudes.resize(kFFTSizeOver2, -160.0f);  // Initialize to very low dB (silence)

        // Create Hann window
        vDSP_hann_window(mWindow.data(), kFFTSize, vDSP_HANN_NORM);

        mCircularBufferWriteIndex = 0;
        mFramesSinceLastFFT = 0;
    }
    
    void teardownFFT() {
        if (mFFTSetup) {
            vDSP_destroy_fftsetup(mFFTSetup);
            mFFTSetup = nullptr;
        }
    }
    
    // MARK: - FFT Processing
    void performFFT() {
        if (!mFFTSetup)
            return;
        
        // Copy from circular buffer to input buffer with proper ordering
        for (size_t i = 0; i < kFFTSize; ++i) {
            size_t readIndex = (mCircularBufferWriteIndex + i) % kFFTSize;
            mFFTInputBuffer[i] = mCircularBuffer[readIndex] * mWindow[i];
        }
        
        // Prepare split complex buffer
        DSPSplitComplex splitComplex;
        auto realPart = std::vector<float>(kFFTSizeOver2);
        auto imagPart = std::vector<float>(kFFTSizeOver2);
        splitComplex.realp = realPart.data();
        splitComplex.imagp = imagPart.data();
        
        // Convert real input to split complex format
        vDSP_ctoz(reinterpret_cast<const DSPComplex*>(mFFTInputBuffer.data()), 2, &splitComplex, 1, kFFTSizeOver2);
        
        // Perform FFT
        vDSP_fft_zrip(mFFTSetup, &splitComplex, 1, mLog2N, FFT_FORWARD);
        
        // Calculate magnitudes
        vDSP_zvmags(&splitComplex, 1, mFFTMagnitudes.data(), 1, kFFTSizeOver2);
        
        // Scale and convert to dB
        float scale = 1.0f / static_cast<float>(kFFTSize);
        vDSP_vsmul(mFFTMagnitudes.data(), 1, &scale, mFFTMagnitudes.data(), 1, kFFTSizeOver2);
        
        // Convert to dB (20 * log10(magnitude))
        for (auto& mag : mFFTMagnitudes) {
            mag = 20.0f * std::log10(std::max(mag, 1e-8f));
        }
    }
    
    // MARK: - Peak Detection
    void detectPeaks() {
        mDetectedPeaks.clear();
        
        // Find local maxima in FFT that exceed threshold
        // Skip first few bins (DC and very low frequencies)
        constexpr size_t kMinBin = 2;
        
        for (size_t i = kMinBin + 1; i < kFFTSizeOver2 - 1; ++i) {
            auto mag = mFFTMagnitudes[i];

            // Check if this is a local maximum above threshold
            // Allow peaks that are equal to or greater than neighbors (relaxed for low frequencies)
            if (mag > kPeakThresholdDB &&
                mag >= mFFTMagnitudes[i - 1] &&
                mag >= mFFTMagnitudes[i + 1]) {
                
                // Convert bin to frequency
                auto freq = (static_cast<float>(i) * mSampleRate) / kFFTSize;

                // Skip frequencies outside audible range (20 Hz - 16384 Hz)
                if (freq < 20.0f || freq > 16384.0f)
                    continue;
                
                // Create detected peak
                auto peak = DetectedPeak{};
                peak.binIndex = i;
                peak.frequency = freq;
                peak.magnitude = mag;
                peak.note = MusicNote::fromFrequency(freq, mag, kReferencePitch);
                
                mDetectedPeaks.push_back(peak);
            }
        }
        
        // Sort by magnitude (strongest first) and keep top N
        std::sort(mDetectedPeaks.begin(), mDetectedPeaks.end(),
                  [](const auto& a, const auto& b) { return a.magnitude > b.magnitude; });
        
        if (mDetectedPeaks.size() > kMaxPeaks)
            mDetectedPeaks.resize(kMaxPeaks);
    }
    
    // MARK: - Member Variables
    AUHostMusicalContextBlock mMusicalContextBlock;
    
    double mSampleRate = 44100.0;
    double mGain = 1.0;
    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;
    
    // FFT members
    FFTSetup mFFTSetup = nullptr;
    vDSP_Length mLog2N = 0;
    std::vector<float> mCircularBuffer;
    std::vector<float> mFFTInputBuffer;
    std::vector<float> mWindow;
    std::vector<float> mFFTMagnitudes;
    size_t mCircularBufferWriteIndex = 0;
    UInt32 mFramesSinceLastFFT = 0;
    
    // Peak detection
    std::vector<DetectedPeak> mDetectedPeaks;
};
