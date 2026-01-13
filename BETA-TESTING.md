# Beta Testing Instructions

## For Beta Testers

### Installation

1. Download the DMG file
2. Double-click to mount it
3. Drag keyq.app to your Applications folder
4. **Important first launch:**
   - Right-click (or Control-click) on keyq.app
   - Select "Open" from the menu
   - Click "Open" in the security dialog
5. After first launch, app opens normally by double-clicking

### Why the extra step?

The app is signed with a development certificate, so macOS requires this one-time approval. This is normal for beta software distributed outside the App Store.

### Using the App

**Standalone Mode:**
- Click "Open" to load an audio file
- Click "Play" to start playback
- Click "Pause" to freeze the FFT and analyse detected notes
- The FFT shows frequency spectrum with detected musical notes below

**As Logic Pro Plugin:**
- Open Logic Pro
- Add keyq as an Audio FX plugin to any audio track
- The plugin will analyse audio in real-time
- Notes detected are shown in the bottom bar

### Feedback

Please report issues with:
- macOS version
- Whether using standalone or plugin mode
- Steps to reproduce any problems
- Screenshots if relevant

## For Developer

### Creating a Beta Build

Run the build script:

```bash
./Scripts/create-dmg.sh
```

This will:
1. Build a Release version
2. Create a DMG on your Desktop
3. Show instructions for testers

### Updating Build Number

The DMG filename includes the git hash for version tracking. Tag releases:

```bash
git tag v0.1.0
./Scripts/create-dmg.sh
```

This creates `keyq-v0.1.0.dmg` instead of `keyq-<hash>.dmg`.
