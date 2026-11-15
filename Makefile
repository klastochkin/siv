.PHONY: all build clean test run install xcode help app run-app tv-test tv-package tv-preview api-test test-all

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

# TV app: logic unit tests (Node built-in runner, no npm install)
tv-test:
	node --test tv/test/*.test.js

# TV app: package .wgt (signed when Tizen CLI is installed). Optional: SERVER=http://192.168.1.50:8080 TOKEN=...
tv-package:
	./tv/build.sh $(if $(SERVER),--server $(SERVER)) $(if $(TOKEN),--token $(TOKEN))

# TV app: open in a desktop browser (arrow keys, Enter, Esc = Back)
tv-preview:
	@echo "Open http://localhost:8000 — point Settings at SIV's TV server"
	cd tv && python3 -m http.server 8000 --bind 127.0.0.1

# API contract test against a running library server: make api-test URL=http://192.168.1.50:8080 [TOKEN=...]
api-test:
	python3 scripts/tv_api_test.py --url $(URL) $(if $(TOKEN),--token $(TOKEN)) --all

# Everything that runs without a TV
test-all: test tv-test

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
	@echo "  make tv-test  - Run TV app logic tests (Node)"
	@echo "  make tv-package [SERVER=url TOKEN=t] - Build tv .wgt"
	@echo "  make tv-preview - Serve TV app for a desktop browser"
	@echo "  make api-test URL=http://ip:port [TOKEN=t] - API contract test"
	@echo "  make test-all - Swift tests + TV logic tests"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "To run as a normal macOS app with menu bar:"
	@echo "  make run-app"
	@echo ""
	@echo "Or build once and run manually:"
	@echo "  make app"
	@echo "  open .build/release/SIV.app"
