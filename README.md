# keyq

Real-time FFT spectrum analyser and pitch detector for macOS, available as both a standalone app and Audio Unit V3 plugin.

## Features

- **High-resolution FFT visualisation** with logarithmic frequency scaling optimised for musical analysis
- **Real-time pitch detection** with musical note identification
- **Adaptive brightness** - frequency bars glow brighter the longer they sustain
- **Height-proportional gradients** - visual depth that responds to signal strength
- **Persistent note labels** - sticky display of sustained pitches
- **Live tuning controls** - adjust all visualisation parameters in real-time during experimentation

## Technical Specifications

- 4096-bin FFT at 44.1/48 kHz sample rates (~10.8 Hz frequency resolution)
- Frequency range: 20 Hz to 16384 Hz
- Logarithmic X-axis scaling for musical frequency distribution
- Exponential smoothing with adjustable response time
- Peak detection with configurable persistence thresholds

## Building

Requires Xcode 16.2+ and macOS 15.2+

```bash
make build-release    # Build optimised release version
make install-app      # Install to /Applications
make clean           # Clean build artefacts
```

## Architecture

### Components

- **keyq.app** - Standalone host application with file playback
- **keyqExtension.appex** - Audio Unit V3 plugin for DAW integration
- **DSP Kernel** (C++) - High-performance FFT processing using vDSP/Accelerate
- **SwiftUI Views** - Modern UI with Canvas-based rendering

### Key Files

- `keyqExtension/DSP/keyqExtensionDSPKernel.hpp` - FFT engine and peak detection
- `keyqExtension/UI/FFTView.swift` - Spectrum visualisation with logarithmic scaling
- `keyqExtension/UI/keyqExtensionMainView.swift` - Main UI and parameter controls
- `keyq/Common/Audio/SimplePlayEngine.swift` - Audio file playback engine

## Live Controls (Experimental)

Click "Show Controls" in the plugin window to access real-time parameter tuning:

| Parameter | Range | Description |
|-----------|-------|-------------|
| FFT Smoothing | 0.0 - 0.5 | Temporal smoothing factor (lower = snappier) |
| Brightness Time | 30 - 180 frames | Time to reach full brightness (~0.5-3s) |
| Brightness Ramp-Up | 0.5 - 5.0 | Speed of brightness increase |
| Brightness Decay | 1.0 - 10.0 | Speed of fade-out when signal stops |
| Note Min Frames | 3 - 60 | Threshold before note label appears |
| Note Decay | 0.5 - 5.0 | How long note labels persist (lower = stickier) |
| Persistence Threshold | -80 to -40 dB | Minimum level to consider bin "active" |

## Usage

### Standalone App

1. Launch keyq.app from /Applications
2. Click "Browse" to load an audio file
3. Press play to visualise audio spectrum

### Audio Unit Plugin

1. Open in any AUv3-compatible DAW (Logic Pro, Ableton Live, etc.)
2. Insert keyqExtension on any audio track
3. Play audio to see real-time spectrum analysis

### Plugin Development

After code changes:

```bash
# Clear Audio Unit cache and re-register
make install-app
killall AudioComponentRegistrar
rm -rf ~/Library/Caches/AudioUnitCache
pluginkit -r
```

Restart your DAW to load the updated plugin.

## Code Style

This project follows modern C++20 and Swift conventions:

- C++ files use `.cxx` extension
- Prefer `constexpr` and `static_assert` for compile-time validation
- Use anonymous namespaces instead of `static` for file scope
- Omit parameter names in C++ headers
- No exceptions - use `std::optional` or early returns
- Modern C++ features: ranges, `std::println`, chrono literals
- SwiftUI with Canvas for high-performance rendering

## Git Workflow

The project uses automated commits with descriptive messages:

```bash
make deploy MSG="your commit message"
```

Always includes:
- Detailed description of WHAT changed and WHY
- "Closes #XX" for issue resolution
- Robot emoji 🤖 prefix (not "Claude" attribution)

## Licence

Copyright © 2026 Dean Turpin

---

**Current Version:** See git hash displayed in app
**Platform:** macOS 15.2+ (Apple Silicon and Intel)
**Audio Unit Type:** Effect (aufx)
**Manufacturer Code:** Audx
