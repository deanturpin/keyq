#!/bin/bash

# Create a DMG for beta distribution

set -e

APP_NAME="keyq"
VERSION=$(git describe --tags --always)
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="${HOME}/Library/Developer/Xcode/DerivedData/keyq-*/Build/Products/Release"
OUTPUT_DIR="${HOME}/Desktop"

echo "Building ${APP_NAME}..."
xcodebuild -scheme keyq -configuration Release clean build

echo "Creating DMG..."
APP_PATH=$(find ${BUILD_DIR} -name "${APP_NAME}.app" -print -quit)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find ${APP_NAME}.app"
    exit 1
fi

# Create temporary directory for DMG contents
TMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TMP_DIR/"

# Create DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDZO \
    "${OUTPUT_DIR}/${DMG_NAME}"

# Clean up
rm -rf "$TMP_DIR"

echo "DMG created: ${OUTPUT_DIR}/${DMG_NAME}"
echo ""
echo "Distribution instructions for beta testers:"
echo "1. Download and mount the DMG"
echo "2. Drag ${APP_NAME}.app to Applications folder"
echo "3. Right-click the app and select 'Open' (first time only)"
echo "4. Click 'Open' in the security dialog"
echo "5. App will open normally after first launch"
