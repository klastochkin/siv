# Makefile for SIV - Simple Image Viewer
# For experienced engineers new to macOS development

.PHONY: help setup build run clean test open debug release install launch

# Default target
help:
	@echo "SIV - Simple Image Viewer"
	@echo ""
	@echo "Available targets:"
	@echo "  make setup      - Initial project setup (creates Xcode project)"
	@echo "  make build      - Build the app (debug mode)"
	@echo "  make run        - Build and run the app"
	@echo "  make launch     - Launch already-built app (no rebuild)"
	@echo "  make test       - Run unit tests"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make open       - Open project in Xcode (for GUI debugging)"
	@echo "  make release    - Build release version"
	@echo "  make install    - Install to /Applications"
	@echo "  make debug      - Build and attach debugger (via Xcode)"
	@echo ""
	@echo "Quick start:"
	@echo "  1. make setup      # One-time setup"
	@echo "  2. make run        # Build and run"
	@echo "  3. make open       # Open in Xcode for debugging"

# Check if Xcode is installed
check-xcode:
	@which xcodebuild > /dev/null || (echo "Error: Xcode not found. Install from App Store." && exit 1)
	@echo "✓ Xcode found"

# Initial setup - creates Xcode project
setup: check-xcode
	@echo "Setting up SIV project..."
	@if [ ! -f "SIV.xcodeproj/project.pbxproj" ]; then \
		echo "Creating Xcode project using swift package..."; \
		swift package init --type executable --name SIV 2>/dev/null || true; \
		echo "Generating Xcode project..."; \
		xcodegen generate || swift package generate-xcodeproj || (echo "Run: ./scripts/create_xcode_project.sh" && exit 1); \
	else \
		echo "✓ Xcode project already exists"; \
	fi
	@echo ""
	@echo "✓ Setup complete!"
	@echo "  Next: make run"

# Build debug version
build: check-xcode
	@echo "Building SIV (Debug)..."
	@if [ -f "SIV.xcodeproj/project.pbxproj" ]; then \
		xcodebuild -project SIV.xcodeproj -scheme SIV -configuration Debug build; \
	else \
		echo "Error: Run 'make setup' first"; \
		exit 1; \
	fi

# Build and run
run: check-xcode
	@echo "Building and running SIV..."
	@if [ -f "SIV.xcodeproj/project.pbxproj" ]; then \
		xcodebuild -project SIV.xcodeproj -scheme SIV -configuration Debug build && \
		APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "SIV.app" -type d 2>/dev/null | head -1) && \
		if [ -n "$$APP_PATH" ]; then \
			echo "Launching $$APP_PATH"; \
			open "$$APP_PATH"; \
		else \
			echo "Error: Could not find SIV.app"; \
			exit 1; \
		fi \
	else \
		echo "Error: Run 'make setup' first"; \
		exit 1; \
	fi

# Launch already-built app (no rebuild)
launch:
	@echo "Launching SIV..."
	@APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "SIV.app" -type d 2>/dev/null | head -1) && \
	if [ -n "$$APP_PATH" ]; then \
		echo "Found: $$APP_PATH"; \
		open "$$APP_PATH"; \
	else \
		echo "Error: App not built yet. Run 'make build' first"; \
		exit 1; \
	fi

# Run tests
test: check-xcode
	@echo "Running tests..."
	@if [ -f "SIV.xcodeproj/project.pbxproj" ]; then \
		xcodebuild test -project SIV.xcodeproj -scheme SIV -destination 'platform=macOS'; \
	else \
		echo "Error: Run 'make setup' first"; \
		exit 1; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build/
	@rm -rf DerivedData/
	@rm -rf .build/
	@if [ -f "SIV.xcodeproj/project.pbxproj" ]; then \
		xcodebuild clean -project SIV.xcodeproj -scheme SIV 2>/dev/null || true; \
	fi
	@echo "✓ Clean complete"

# Open in Xcode (best for debugging)
open: check-xcode
	@if [ -f "SIV.xcodeproj/project.pbxproj" ]; then \
		echo "Opening in Xcode..."; \
		open SIV.xcodeproj; \
	else \
		echo "Error: Run 'make setup' first"; \
		exit 1; \
	fi

# Build and debug in Xcode
debug: check-xcode
	@echo "Opening in Xcode for debugging..."
	@echo "Once Xcode opens, press ⌘R to run with debugger attached"
	@$(MAKE) open

# Build release version
release: check-xcode
	@echo "Building SIV (Release)..."
	@if [ -f "SIV.xcodeproj/project.pbxproj" ]; then \
		xcodebuild -project SIV.xcodeproj -scheme SIV -configuration Release build; \
	else \
		echo "Error: Run 'make setup' first"; \
		exit 1; \
	fi
	@echo "✓ Release build complete"
	@echo "  App location: build/Release/SIV.app"

# Install to /Applications
install: release
	@echo "Installing SIV to /Applications..."
	@cp -R build/Release/SIV.app /Applications/
	@echo "✓ Installed to /Applications/SIV.app"

# Show project info
info:
	@echo "Project: SIV - Simple Image Viewer"
	@echo "Language: Swift 5.9+"
	@echo "Platform: macOS 13.0+"
	@echo "Architecture: Universal (Intel + Apple Silicon)"
	@echo ""
	@echo "Project structure:"
	@find SIV -name "*.swift" | head -10
	@echo "..."

