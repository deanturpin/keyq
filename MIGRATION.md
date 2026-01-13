# keyq V3 Audio Unit Migration

## Overview

Successfully migrated keyq from a command-line Audio Unit V2 approach to a modern Audio Unit V3 plugin using Xcode. The decision to use Xcode was made after discovering the complexity of properly configuring AUv3 extensions from scratch via command line.

## Why Xcode?

Audio Unit V3 uses App Extensions, which require:
- Complex entitlements and code signing
- Precise Info.plist configuration for AU registration
- SwiftUI hosting for modern UI
- Proper sandboxing and security settings

Xcode's AU template handles all of this automatically, saving significant configuration headaches.

## Architecture

### Components

1. **Host App** (`keyq/`)
   - SwiftUI application for testing and hosting the AU
   - Loads and validates the Audio Unit
   - Provides audio playback controls
   - Displays AU validation results

2. **Audio Unit Extension** (`keyqExtension/`)
   - App Extension containing the actual plugin
   - C++ DSP kernel for real-time processing
   - Swift AUv3 wrapper
   - SwiftUI parameter UI

### Audio Unit Details

- **Type**: Effect (aufx)
- **Subtype**: keyq
- **Manufacturer**: Audx
- **Channels**: Stereo in/out (2 channels)
- **Current Features**: Gain control (0.0-1.0)

## Project Structure

```
keyq/
├── Makefile                    # Command-line build workflow
├── keyq.xcodeproj/            # Xcode project
├── keyq/                       # Host application
│   ├── Common/
│   │   ├── Audio/             # Audio engine
│   │   └── MIDI/              # MIDI management
│   ├── Model/                 # View models
│   └── ContentView.swift      # Main UI
└── keyqExtension/             # Audio Unit extension
    ├── DSP/                   # C++ processing kernel
    │   └── keyqExtensionDSPKernel.hpp
    ├── UI/                    # SwiftUI interface
    │   ├── keyqExtensionMainView.swift
    │   └── ParameterSlider.swift
    ├── Common/
    │   ├── Audio Unit/        # AU implementation
    │   └── UI/                # View controller
    ├── Parameters/            # Parameter definitions
    └── Info.plist            # AU metadata

```

## Build Workflow

### Using Make (Recommended)

```bash
make              # Build and install
make clean        # Clean build artifacts
make run          # Launch host app
make help         # Show all targets
```

### Using Xcode

1. Open `keyq.xcodeproj`
2. Select the `keyq` scheme
3. Build and run (⌘R)

The Audio Unit automatically registers when the host app launches.

## Technical Details

### DSP Processing

The C++ kernel (`keyqExtensionDSPKernel.hpp`) handles real-time audio:
- Process callback: sample-by-sample or block processing
- Parameter automation support
- Bypass functionality
- Musical context access (tempo, time signature)

### Parameter System

Parameters defined in `Parameters.swift`:
- Gain (0.0-1.0, default 0.25)
- Observable via SwiftUI bindings
- Automatable from host DAW

### UI Integration

SwiftUI view (`keyqExtensionMainView`) displays:
- Parameter sliders with min/max labels
- Real-time parameter updates
- Custom styling and layout

## Critical Fixes

### Manufacturer Code Case Sensitivity

**Issue**: App crashed on launch with "Failed to find component"

**Cause**: Manufacturer FourCC code mismatch:
- Host app: `audx` (lowercase)
- AU extension: `Audx` (capital A)

**Solution**: Standardised on `Audx` in both:
- `AudioUnitHostModel.swift`: `manufacturer: "Audx"`
- `Info.plist`: `<string>Audx</string>`

Audio Unit FourCC codes are case-sensitive strings.

### UI Visibility

**Issue**: AU UI was loading but not visible

**Solution**: Added explicit frame size, background, and title:
```swift
VStack {
    Text("keyq Audio Unit")
        .font(.headline)
    ParameterSlider(param: parameterTree.global.gain)
}
.frame(minWidth: 400, minHeight: 200)
.background(Color.gray.opacity(0.1))
```

## Verification

The plugin is successfully registered and functional:

```bash
# Check registration
pluginkit -m -p com.apple.AudioUnit-UI | grep keyq
# Output: Audieaux.keyq.keyqExtension(1.0)

# Validate AU
auval -a | grep keyq
# Output: aufx keyq Audx  -  Audieaux: keyqExtension
```

## Next Steps

Now that the V3 infrastructure is working:

1. **FFT Implementation**
   - Add real-time frequency analysis
   - Logarithmic X-axis for musical analysis
   - Visualisation in AU UI

2. **Pitch Quantisation**
   - Detect fundamental frequency
   - Quantise to nearest musical note
   - MIDI output support

3. **Enhanced Parameters**
   - Sensitivity control
   - Frequency range selection
   - Quantisation mode (chromatic, scale, etc.)

4. **UI Improvements**
   - FFT spectrum display
   - Note detection visualisation
   - Real-time pitch tracking

## Resources

- [Apple Audio Unit Programming Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/)
- [Creating Audio Unit Extensions](https://developer.apple.com/documentation/audiotoolbox/creating_audio_unit_extensions)
- [AUv3 Best Practices](https://developer.apple.com/documentation/audiotoolbox/audio_unit_v3_plug-ins)

## Lessons Learned

1. **Use Xcode for AUv3**: The template handles critical configuration automatically
2. **Case sensitivity matters**: FourCC codes must match exactly
3. **Explicit UI sizing**: SwiftUI views need clear dimensions in AU context
4. **Command-line builds still possible**: Xcode generates the project, Make handles iteration
5. **Validation is your friend**: `auval` catches issues early

---

**Status**: ✅ Audio Unit V3 working, validated, and processing audio  
**Ready for**: FFT implementation and pitch detection logic
