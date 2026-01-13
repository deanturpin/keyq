#!/bin/bash

# Get the git commit hash
GIT_HASH=$(git -C "${SRCROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Create the Swift file
cat > "${SRCROOT}/keyqExtension/Generated/GitHash.swift" << SWIFT_EOF
// Auto-generated file - do not edit
// Generated at build time with current git commit hash

struct GitHash {
    static let hash = "${GIT_HASH}"
}
SWIFT_EOF
