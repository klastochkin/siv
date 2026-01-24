.PHONY: all build clean test run install xcode help app run-app

# Default target
all: build

# Build the application (executable only)
build:
	@echo "Building SIV..."
	swift build -c release

# Build for debugging
debug:
	@echo "Building SIV (debug)..."
	swift build

# Build app bundle (.app)
app:
	@echo "Building SIV.app bundle..."
	@./scripts/build_app_bundle.sh

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build
	rm -rf SIV.xcodeproj

# Run tests
test:
	@echo "Running tests..."
	swift test

# Run the application (executable)
run:
	@echo "Running SIV..."
	swift run

# Build and run app bundle (standalone app with menu bar)
run-app: app
	@echo "Launching SIV.app..."
	@open .build/release/SIV.app

# Install to /Applications
install: app
	@echo "Installing SIV to /Applications..."
	@if [ -d ".build/release/SIV.app" ]; then \
		cp -R .build/release/SIV.app /Applications/; \
		echo "✅ SIV installed to /Applications/SIV.app"; \
		echo ""; \
		echo "You can now:"; \
		echo "  - Launch from Applications folder"; \
		echo "  - Use Cmd+Tab to switch to it"; \
		echo "  - See the app's own menu bar"; \
	else \
		echo "❌ Error: SIV.app not found in .build/release/"; \
		echo "Run 'make app' first to build the app bundle."; \
		exit 1; \
	fi

# Generate Xcode project
xcode:
	@echo "Generating Xcode project..."
	swift package generate-xcodeproj
	@echo "Opening Xcode project..."
	open SIV.xcodeproj

# Show help
help:
	@echo "SIV - Simple Image Viewer"
	@echo ""
	@echo "Available targets:"
	@echo "  make build    - Build release executable"
	@echo "  make debug    - Build debug executable"
	@echo "  make app      - Build app bundle (.app) - RECOMMENDED"
	@echo "  make run      - Run executable (no menu bar)"
	@echo "  make run-app  - Build and run app bundle (standalone app)"
	@echo "  make install  - Build app bundle and install to /Applications"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make test     - Run unit tests"
	@echo "  make xcode    - Generate and open Xcode project"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "To run as a normal macOS app with menu bar:"
	@echo "  make run-app"
	@echo ""
	@echo "Or build once and run manually:"
	@echo "  make app"
	@echo "  open .build/release/SIV.app"
