#!/bin/bash

# Build and install keyq to Applications directory

set -e

APP_NAME="keyq"
BUILD_CONFIG="Release"
BUILD_DIR="${HOME}/Library/Developer/Xcode/DerivedData/keyq-*/Build/Products/${BUILD_CONFIG}"
INSTALL_DIR="/Applications"

echo "Building ${APP_NAME}..."
xcodebuild -scheme keyq -configuration ${BUILD_CONFIG} clean build

echo "Finding built app..."
APP_PATH=$(find ${BUILD_DIR} -name "${APP_NAME}.app" -print -quit)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find ${APP_NAME}.app"
    exit 1
fi

echo "Installing to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
cp -R "$APP_PATH" "${INSTALL_DIR}/"

echo "Installation complete: ${INSTALL_DIR}/${APP_NAME}.app"
