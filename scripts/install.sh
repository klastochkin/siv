#!/bin/bash
# Installation script for SIV development environment

set -e

echo "================================"
echo "SIV Development Setup"
echo "================================"
echo ""

# Check OS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This is a macOS-only project"
    exit 1
fi

echo "✓ macOS detected"
echo ""

# Check if Xcode Command Line Tools are installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo ""
    echo "⏳ Please complete the installation dialog, then run this script again"
    exit 0
fi

echo "✓ Xcode Command Line Tools found"
echo ""

# Check if full Xcode is installed
XCODE_PATH="/Applications/Xcode.app"
if [ -d "$XCODE_PATH" ]; then
    echo "✓ Full Xcode found at $XCODE_PATH"
    xcodebuild -version | head -1
    HAS_XCODE=true
else
    echo "⚠️  Full Xcode not found (only Command Line Tools)"
    echo ""
    echo "You have two options:"
    echo ""
    echo "Option 1: Install full Xcode (recommended for GUI debugging)"
    echo "  - Download from App Store: https://apps.apple.com/us/app/xcode/id497799835"
    echo "  - Size: ~15GB"
    echo "  - Provides GUI debugger, Interface Builder, etc."
    echo ""
    echo "Option 2: Continue with Command Line Tools only"
    echo "  - You can still build and run"
    echo "  - No GUI debugger"
    echo "  - Faster setup"
    echo ""
    read -p "Continue with Command Line Tools only? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please install Xcode from App Store and run this script again"
        exit 0
    fi
    HAS_XCODE=false
fi

echo ""

# Check for xcodegen (optional, makes project setup easier)
if command -v xcodegen &> /dev/null; then
    echo "✓ xcodegen found"
    HAS_XCODEGEN=true
else
    echo "⚠️  xcodegen not found"
    echo ""
    echo "xcodegen makes project setup easier. Install it?"
    echo "  Installation: brew install xcodegen"
    echo ""
    read -p "Install xcodegen via Homebrew? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v brew &> /dev/null; then
            brew install xcodegen
            HAS_XCODEGEN=true
        else
            echo "Homebrew not found. Install from: https://brew.sh"
            HAS_XCODEGEN=false
        fi
    else
        HAS_XCODEGEN=false
    fi
fi

echo ""
echo "================================"
echo "Setup Summary"
echo "================================"
echo ""
echo "Xcode (Full):     $( [ "$HAS_XCODE" = true ] && echo "✓ Yes" || echo "✗ No (CLI Tools only)" )"
echo "xcodegen:         $( [ "$HAS_XCODEGEN" = true ] && echo "✓ Yes" || echo "✗ No" )"
echo ""

# Create Xcode project
echo "================================"
echo "Creating Xcode Project"
echo "================================"
echo ""

if [ "$HAS_XCODEGEN" = true ]; then
    echo "Using xcodegen..."
    xcodegen generate
    echo "✓ Project created: SIV.xcodeproj"
else
    echo "Manual project creation required."
    echo ""
    echo "Run: ./scripts/create_xcode_project.sh"
    echo ""
fi

echo ""
echo "================================"
echo "✅ Setup Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo ""
if [ "$HAS_XCODE" = true ]; then
    echo "  make open     # Open in Xcode"
    echo "  make run      # Build and run"
else
    echo "  make build    # Build the app"
    echo "  make run      # Run the app"
fi
echo ""
echo "See QUICKSTART.md for detailed instructions"
echo ""

