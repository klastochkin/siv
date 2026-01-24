#!/bin/bash
# Build a proper macOS app bundle from the Swift package
# This creates SIV.app that can be run independently

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="SIV"
APP_BUNDLE="$BUILD_DIR/release/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME.app bundle..."
echo ""

# Build the executable
echo "Step 1: Building Swift executable..."
cd "$PROJECT_DIR"
swift build -c release

# Get the executable path
EXECUTABLE="$BUILD_DIR/release/$APP_NAME"

if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Error: Executable not found at $EXECUTABLE"
    exit 1
fi

# Create app bundle structure
echo "Step 2: Creating app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Create Info.plist
echo "Step 3: Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.siv.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.graphics-design</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Image</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.jpeg</string>
                <string>public.png</string>
                <string>public.heif</string>
                <string>public.heic</string>
                <string>public.tiff</string>
                <string>com.adobe.photoshop-image</string>
                <string>public.image</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# Create PkgInfo (optional but helps)
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo ""
echo "✅ App bundle created: $APP_BUNDLE"
echo ""
echo "To run the app:"
echo "  open $APP_BUNDLE"
echo ""
echo "Or from project root:"
echo "  open .build/release/$APP_NAME.app"
echo ""
