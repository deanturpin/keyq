.PHONY: all build build-debug build-release clean install install-app run help

# Default target (use Release for performance)
all: build-release install

# Build Release (optimised for performance)
build: build-release

build-release:
	@echo "Building keyq Audio Unit (Release - optimised)..."
	xcodebuild -scheme keyq -configuration Release build

# Build Debug (for development/debugging)
build-debug:
	@echo "Building keyq Audio Unit (Debug)..."
	xcodebuild -scheme keyq -configuration Debug build

# Install to /Applications and register the Audio Unit
install: install-app
	@echo "Registering Audio Unit..."
	@open /Applications/keyq.app
	@sleep 2
	@echo "Verifying installation..."
	@pluginkit -m -p com.apple.AudioUnit-UI | grep -i keyq || echo "Warning: Plugin not found yet, may need a moment to register"

# Copy built app to /Applications
install-app:
	@echo "Installing to /Applications..."
	@APP_PATH=$$(ls -td ~/Library/Developer/Xcode/DerivedData/keyq-*/Build/Products/Release/keyq.app ~/Library/Developer/Xcode/DerivedData/keyq-*/Build/Products/Debug/keyq.app 2>/dev/null | head -1); \
	if [ -d "$$APP_PATH" ] && [ -x "$$APP_PATH/Contents/MacOS/keyq" ]; then \
		echo "Copying $$APP_PATH to /Applications/"; \
		rm -rf /Applications/keyq.app; \
		cp -R "$$APP_PATH" /Applications/; \
		echo "✓ Installed to /Applications/keyq.app"; \
	else \
		echo "Error: App not found or executable missing at $$APP_PATH"; \
		exit 1; \
	fi

# Run the installed app from /Applications
run:
	@if [ -d "/Applications/keyq.app" ]; then \
		open /Applications/keyq.app; \
	else \
		echo "Error: App not installed. Run 'make install' first."; \
		exit 1; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	xcodebuild -scheme keyq -configuration Release clean
	xcodebuild -scheme keyq -configuration Debug clean

# Show available targets
help:
	@echo "Available targets:"
	@echo "  make              - Build Release and install to /Applications (default)"
	@echo "  make build        - Build Release (optimised)"
	@echo "  make build-release - Build Release configuration (optimised)"
	@echo "  make build-debug  - Build Debug configuration"
	@echo "  make install      - Copy to /Applications and register AU"
	@echo "  make run          - Run the installed app from /Applications"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make help         - Show this help message"
