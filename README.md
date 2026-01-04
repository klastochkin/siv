# SIV - Simple Image Viewer for macOS

A minimal, native macOS image viewer built with Swift and SwiftUI for learning purposes.

## Features (Phase 1)

- 📂 Open JPEG, PNG, and HEIF images
- 🖼️ Clean, distraction-free viewing interface
- ⌨️ Keyboard-driven navigation
- 🔍 Zoom and pan support
- 📊 Image information display
- 🎨 Light/dark mode support
- ⚡ Fast performance with image caching

## Screenshots

*(Screenshots will be added after implementation)*

## Getting Started

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/siv.git
cd siv
```

2. Open in Xcode:
```bash
open SIV.xcodeproj
```

3. Build and run (⌘+R)

## Usage

### Opening Images

- **Drag & Drop**: Drag an image file onto the SIV app icon or window
- **File Menu**: Use File → Open (⌘O) to browse for an image
- **Right-click**: Right-click an image in Finder → Open With → SIV

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘O` | Open file |
| `⌘W` | Close window |
| `⌘Q` | Quit app |
| `→` or `Space` | Next image |
| `←` | Previous image |
| `⌘+` or `⌘=` | Zoom in |
| `⌘-` | Zoom out |
| `⌘0` | Fit to window |
| `⌘1` | Actual size (100%) |
| `I` | Toggle info bar |
| `Esc` | Close window |

### Mouse & Trackpad

- **Scroll wheel**: Zoom in/out (centered on cursor)
- **Pinch gesture**: Zoom in/out
- **Click & drag**: Pan when zoomed in

## Project Structure

```
siv/
├── SIV/
│   ├── App/                    # App entry point and delegate
│   ├── Views/                  # SwiftUI views
│   ├── ViewModels/             # MVVM view models
│   ├── Models/                 # Data models
│   ├── Services/               # Business logic services
│   ├── Utilities/              # Helper extensions
│   └── Resources/              # Assets and resources
├── SIVTests/                   # Unit tests
└── docs/                       # Documentation
    ├── requirements.md         # Product requirements
    └── phase1-design.md        # Phase 1 design document
```

## Architecture

SIV follows the **MVVM (Model-View-ViewModel)** architecture pattern:

- **Models**: Data structures (`ImageFile`, `ZoomState`)
- **Views**: SwiftUI views (`ImageViewerWindow`, `ImageCanvas`, `InfoBar`)
- **ViewModels**: Business logic and state management (`ImageViewModel`)
- **Services**: Reusable services (`ImageLoader`, `FileNavigator`, `ImageCache`)

## Roadmap

### ✅ Phase 1 (Current)
- Core viewing functionality
- Navigation and zoom
- Basic information display

### 🔜 Phase 2 (Planned)
- Thumbnail grid view
- Basic editing (rotate, crop)
- EXIF data viewing/editing
- Folder watching
- Slideshow mode

## Contributing

This is a personal learning project, but suggestions and feedback are welcome! Please open an issue to discuss any changes.

## Testing

Run tests in Xcode:
```bash
⌘+U
```

Or via command line:
```bash
xcodebuild test -scheme SIV
```

## Performance

Target metrics:
- **Cold start**: <1 second
- **Image load** (5MB): <200ms
- **Navigation**: <100ms
- **Memory**: <500MB cache limit

## License

MIT License - See LICENSE file for details

## Acknowledgments

Built as a learning project to explore:
- SwiftUI app development
- macOS native development
- MVVM architecture
- Image processing with CoreImage/ImageIO
- Performance optimization

## Contact

For questions or feedback, please open an issue on GitHub.

---

**Status**: 🚧 In Development (Phase 1)
