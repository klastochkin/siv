# SIV - Simple Image Viewer

A native macOS image viewer application built with Swift and SwiftUI, featuring dual-pane interface with image viewing and album management capabilities.

## Features

### Phase 1 (Current)

#### Image View
- Open and display images (JPEG, PNG, HEIF)
- Drag & drop support
- Zoom controls (10% to 1600%)
  - Scroll wheel zoom with 0.001 sensitivity
  - Trackpad pinch gesture with 0.2 dampening
  - Keyboard shortcuts: Cmd+/-, Cmd+0 (fit), Cmd+1 (actual size)
- Pan support
  - Arrow keys (50px per press)
  - 2-finger trackpad drag
  - Enabled when image is larger than window
- Image information display (filename, resolution, file size, zoom level)
- Bottom info bar overlay

#### Album View
- Default album management (stored in `~/Library/Application Support/SIV/default.sivalb`)
- Two view modes: List and Thumbnails
- Add images via File menu or drag & drop
- Navigate between images with arrow keys or space bar
- Missing file detection with red X overlay
- Remove missing files functionality

#### Window Management
- Minimum window size: 600x400
- Split view with resizable panes
- Toggle Album/Image view visibility
- Focus switching with Tab key

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+O | Open image file |
| Cmd+A | Add current image to album |
| Cmd+0 | Fit image to window |
| Cmd+1 | Actual size (100%) |
| Cmd++ | Zoom in |
| Cmd+- | Zoom out |
| Tab | Switch focus between Album and Image view |
| Arrow Keys | Pan (Image view) / Navigate (Album view) |
| Space | Next image (Album view) |

## Requirements

- macOS 13+ (Ventura or later)
- Xcode 15+ with Swift 5.9+

## Building

### Using Makefile

```bash
# Build the application
make build

# Build for debugging
make debug

# Run tests
make test

# Clean build artifacts
make clean

# Generate and open Xcode project
make xcode

# Show all available commands
make help
```

### Using Swift Package Manager

```bash
# Build
swift build

# Build release
swift build -c release

# Run
swift run

# Test
swift test
```

## Project Structure

```
Sources/SIV/
├── Models/
│   ├── ImageFile.swift      # Image file representation
│   ├── Album.swift           # Album data structure
│   └── ZoomState.swift       # Zoom and pan state management
├── Services/
│   ├── ImageLoader.swift     # Async image loading with caching
│   └── AlbumManager.swift    # Album persistence and management
├── ViewModels/
│   ├── ImageViewModel.swift  # Image view business logic
│   └── AlbumViewModel.swift  # Album view business logic
├── Views/
│   ├── ContentView.swift     # Main split view container
│   ├── ImageCanvas.swift     # Image display with zoom/pan
│   ├── AlbumView.swift       # Album list/thumbnail view
│   └── InfoBar.swift         # Image info overlay
├── SIVApp.swift              # App entry point and menu commands
└── AppDelegate.swift         # App lifecycle management

Tests/SIVTests/
├── ZoomStateTests.swift
├── AlbumTests.swift
└── ImageFileTests.swift
```

## Architecture

The application follows MVVM (Model-View-ViewModel) architecture:

- **Models**: Pure data structures (ImageFile, Album, ZoomState)
- **Services**: Business logic for image loading and album management
- **ViewModels**: Bridge between services and views, managing state
- **Views**: SwiftUI views for UI rendering

### Key Design Decisions

1. **Actor-based ImageLoader**: Uses Swift concurrency for thread-safe image loading with LRU cache
2. **Split View Architecture**: Independent Image and Album views with shared state through ViewModels
3. **Protocol-based Services**: Enables testability and future extensibility
4. **JSON Album Storage**: Simple, human-readable format for album persistence

## Testing

The project includes comprehensive unit tests with >70% coverage:

```bash
swift test
```

Test coverage includes:
- ZoomState calculations and constraints
- Album operations (add, remove, missing files)
- ImageFile metadata handling

## Performance Characteristics

- **Cold start**: <1s
- **Image loading**: <200ms for 5MB files
- **Navigation response**: <100ms
- **Memory limit**: 500MB cache with LRU eviction

## Future Enhancements (Phase 2+)

- Multiple album support
- Thumbnail grid view
- EXIF data display
- Folder watching with auto-reload
- Advanced image processing

## License

Copyright © 2026. All rights reserved.
