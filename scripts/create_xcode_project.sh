#!/bin/bash
# Script to create Xcode project for SIV
# Run this once to set up the project

set -e  # Exit on error

echo "================================"
echo "SIV Xcode Project Setup"
echo "================================"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode not installed"
    echo "   Install from: https://apps.apple.com/us/app/xcode/id497799835"
    exit 1
fi

echo "✓ Xcode found: $(xcodebuild -version | head -1)"
echo ""

# Create Xcode project using xcodegen (if available) or manually
if command -v xcodegen &> /dev/null; then
    echo "Using xcodegen to create project..."
    xcodegen generate
else
    echo "Creating Xcode project manually..."
    
    # Create a minimal Xcode project structure
    PROJECT_DIR="SIV.xcodeproj"
    
    if [ -d "$PROJECT_DIR" ]; then
        echo "⚠️  Project already exists at $PROJECT_DIR"
        read -p "   Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
        rm -rf "$PROJECT_DIR"
    fi
    
    mkdir -p "$PROJECT_DIR"
    
    # Create project.pbxproj file
    cat > "$PROJECT_DIR/project.pbxproj" << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {
		// This is a placeholder project file
		// Open this in Xcode and it will help you set up properly
	};
	rootObject = PLACEHOLDER;
}
EOF
    
    echo ""
    echo "⚠️  Created placeholder project file"
    echo ""
    echo "📝 MANUAL SETUP REQUIRED:"
    echo ""
    echo "Since xcodegen is not installed, you need to create the project manually:"
    echo ""
    echo "1. Open Xcode"
    echo "2. File → New → Project"
    echo "3. Choose: macOS → App"
    echo "4. Configure:"
    echo "   - Product Name: SIV"
    echo "   - Interface: SwiftUI"
    echo "   - Language: Swift"
    echo "   - Include Tests: ✓"
    echo "5. Save to: $(pwd)"
    echo "   (Choose the CURRENT directory, not a subdirectory)"
    echo "6. In Xcode, delete the default ContentView.swift"
    echo "7. Add existing files:"
    echo "   - Right-click project → Add Files to SIV"
    echo "   - Select the SIV/ folder"
    echo "   - ✓ Create groups"
    echo "   - ✓ Add to targets: SIV"
    echo "8. Add test files:"
    echo "   - Right-click SIVTests → Add Files to SIV"
    echo "   - Select the SIVTests/ folder"
    echo "   - ✓ Add to targets: SIVTests"
    echo ""
    echo "After manual setup, you can use:"
    echo "  make build    # Build the project"
    echo "  make run      # Run the app"
    echo "  make test     # Run tests"
    echo ""
    exit 0
fi

echo ""
echo "================================"
echo "✅ Setup Complete!"
echo "================================"
echo ""
echo "Next steps:"
echo "  make build    # Build the project"
echo "  make run      # Build and run"
echo "  make open     # Open in Xcode for GUI debugging"
echo ""

