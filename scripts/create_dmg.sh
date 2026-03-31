#!/bin/bash
set -e

APP_NAME="TapLauncher"
VERSION="${1:-1.0.0}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOL_NAME="${APP_NAME}"
STAGING_DIR=".build/dmg_staging"
TEMP_DMG=".build/temp.dmg"
BG_IMG="Resources/dmg_background.png"

echo "Creating styled DMG..."

# Generate background if missing
if [ ! -f "$BG_IMG" ]; then
    echo "Generating DMG background..."
    mkdir -p Resources
    swift scripts/generate_dmg_background.swift "$BG_IMG"
fi

# Clean up any previous attempts
rm -rf "$STAGING_DIR" "$DMG_NAME" "$TEMP_DMG"
hdiutil detach "/Volumes/${VOL_NAME}" 2>/dev/null || true

# Create staging area
mkdir -p "$STAGING_DIR/.background"
cp -R "${APP_NAME}.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$BG_IMG" "$STAGING_DIR/.background/background.png"

# Create read-write DMG
hdiutil create \
    -srcfolder "$STAGING_DIR" \
    -volname "$VOL_NAME" \
    -fs HFS+ \
    -format UDRW \
    -size 50m \
    "$TEMP_DMG"

# Mount it
DEVICE=$(hdiutil attach -readwrite -noverify "$TEMP_DMG" | awk '/Apple_HFS/{print $1}')
sleep 3

# Apply Finder layout with AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 860, 640}

        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"

        set position of item "${APP_NAME}.app" to {160, 180}
        set position of item "Applications" to {500, 180}

        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

sleep 2

# Unmount
sync
hdiutil detach "$DEVICE"
sleep 1

# Convert to compressed read-only DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

# Clean up
rm -rf "$STAGING_DIR" "$TEMP_DMG"

echo "Created $DMG_NAME ($(du -h "$DMG_NAME" | awk '{print $1}'))"
