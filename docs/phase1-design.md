# Phase 1 Design Document - SIV (Simple Image Viewer)

**Version:** 1.0  
**Date:** January 2, 2026  
**Status:** Planning

---

## Overview
A minimal, native macOS image viewer focused on speed and simplicity. Phase 1 delivers core viewing functionality with keyboard-driven navigation and basic zoom capabilities.

## Goals
- Fast startup and image loading (<1s)
- Intuitive, distraction-free UI
- Smooth navigation between images
- Native macOS look and feel

## Non-Goals (Phase 1)
- Image editing (Phase 2)
- Thumbnail grid view (Phase 2)
- Slideshow mode (Phase 2)
- Folder monitoring (Phase 2)

---

## User Stories

### US-1: Open an Image
**As a** user  
**I want to** open an image file from Finder  
**So that** I can view it quickly

**Acceptance Criteria:**
- User can drag & drop image onto app icon
- User can use Cmd+O to browse for file
- User can right-click image → "Open With" → SIV
- Supported formats: JPEG, PNG, HEIF
- Invalid files show error message

### US-2: View Image Details
**As a** user  
**I want to** see basic image information  
**So that** I understand what I'm looking at

**Acceptance Criteria:**
- Info bar shows: filename, dimensions, file size, zoom level
- Info bar can be toggled with "I" key
- Info updates when navigating to different images

### US-3: Navigate Between Images
**As a** user  
**I want to** browse images in the same folder  
**So that** I don't have to open each file individually

**Acceptance Criteria:**
- Arrow keys (←/→) navigate to prev/next image
- Space bar navigates to next image
- Navigation wraps around (last → first)
- Only supported image formats are included
- Files sorted alphabetically

### US-4: Zoom In/Out
**As a** user  
**I want to** zoom into image details  
**So that** I can inspect images closely

**Acceptance Criteria:**
- Scroll wheel zooms in/out (centered on cursor)
- Trackpad pinch gesture zooms
- Cmd+0 resets to "fit to window"
- Cmd+= zooms in, Cmd+- zooms out
- Zoom range: 10% to 1600%
- When zoomed in, can pan by clicking and dragging

---

## UI Specification

### Window Layout

```
┌─────────────────────────────────────────────────┐
│ File   View   Window   Help              ●●●    │
├─────────────────────────────────────────────────┤
│                                                 │
│                                                 │
│                                                 │
│             [IMAGE DISPLAY AREA]                │
│                Canvas-based, centered           │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
├─────────────────────────────────────────────────┤
│ 📄 image.jpg  •  1920x1080  •  2.4 MB  •  100% │
└─────────────────────────────────────────────────┘
```

### Menu Structure

**File Menu:**
- Open... (Cmd+O)
- Close Window (Cmd+W)
- ---
- Quit (Cmd+Q)

**View Menu:**
- Zoom In (Cmd+=)
- Zoom Out (Cmd+-)
- Actual Size (Cmd+1)
- Fit to Window (Cmd+0)
- ---
- Toggle Info Bar (I)
- ---
- Next Image (→ or Space)
- Previous Image (←)

**Window Menu:**
- (Standard macOS window controls)

**Help Menu:**
- SIV Help
- Keyboard Shortcuts

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Cmd+O | Open file |
| Cmd+W | Close window |
| Cmd+Q | Quit app |
| → or Space | Next image |
| ← | Previous image |
| Cmd+= | Zoom in |
| Cmd+- | Zoom out |
| Cmd+0 | Fit to window |
| Cmd+1 | Actual size (100%) |
| I | Toggle info bar |
| Esc | Exit fullscreen / Close window |

### Visual Design

**Color Scheme:**
- Background: System background (adapts to light/dark mode)
  - Light: `#F5F5F5` (off-white)
  - Dark: `#1E1E1E` (charcoal)
- Info bar: Semi-transparent overlay
  - Light: `rgba(255, 255, 255, 0.95)`
  - Dark: `rgba(30, 30, 30, 0.95)`
- Text: System primary/secondary labels

**Typography:**
- Info bar: SF Pro Text, 12pt
- Filename: Medium weight
- Metadata: Regular weight, secondary color

**Spacing:**
- Window minimum size: 400x300
- Info bar height: 32px
- Info bar padding: 12px horizontal, 8px vertical
- Image padding: 20px from edges when fit-to-window

---

## Technical Architecture

### Technology Stack
- **Language:** Swift 5.9+
- **Framework:** SwiftUI
- **Min OS:** macOS 13.0 (Ventura)
- **Build System:** Xcode 15+

### Project Structure

```
siv/
├── SIV/
│   ├── App/
│   │   ├── SIVApp.swift              # App entry point
│   │   └── AppDelegate.swift         # Menu bar, app lifecycle
│   ├── Views/
│   │   ├── ImageViewerWindow.swift   # Main window
│   │   ├── ImageCanvas.swift         # Zoomable image display
│   │   └── InfoBar.swift             # Bottom info overlay
│   ├── ViewModels/
│   │   └── ImageViewModel.swift      # Image state, navigation, zoom
│   ├── Models/
│   │   ├── ImageFile.swift           # Image metadata model
│   │   └── ZoomState.swift           # Zoom level, pan offset
│   ├── Services/
│   │   ├── ImageLoader.swift         # Load/decode images
│   │   ├── FileNavigator.swift       # Navigate folder contents
│   │   └── ImageCache.swift          # Memory management
│   ├── Utilities/
│   │   ├── FileSize+Extensions.swift # Format bytes
│   │   └── URL+Extensions.swift      # File handling helpers
│   └── Resources/
│       ├── Assets.xcassets            # App icon, colors
│       └── Info.plist                 # App metadata, file types
├── SIVTests/
│   ├── FileNavigatorTests.swift
│   ├── ImageLoaderTests.swift
│   └── ZoomStateTests.swift
└── docs/
    ├── requirements.md
    └── phase1-design.md
```

### Key Components

#### 1. ImageViewModel
**Responsibilities:**
- Maintain current image state
- Handle navigation (next/prev)
- Manage zoom state (level, offset)
- Load images via ImageLoader
- Expose UI state to SwiftUI views

**Properties:**
```swift
@Published var currentImage: NSImage?
@Published var currentFile: ImageFile?
@Published var zoomState: ZoomState
@Published var isInfoBarVisible: Bool
var availableImages: [ImageFile]
var currentIndex: Int
```

**Methods:**
```swift
func openImage(at url: URL)
func navigateNext()
func navigatePrevious()
func zoomIn()
func zoomOut()
func resetZoom()
func fitToWindow(size: CGSize)
```

#### 2. ImageLoader
**Responsibilities:**
- Asynchronously load images from disk
- Decode supported formats (JPEG, PNG, HEIF)
- Handle errors gracefully
- Provide metadata (dimensions, file size)

**Methods:**
```swift
func loadImage(from url: URL) async throws -> NSImage
func getMetadata(for url: URL) throws -> ImageMetadata
```

#### 3. FileNavigator
**Responsibilities:**
- Scan folder for supported images
- Sort images alphabetically
- Provide next/previous navigation
- Filter by supported extensions

**Methods:**
```swift
func getImagesInFolder(of fileURL: URL) throws -> [ImageFile]
func nextImage(after current: ImageFile) -> ImageFile?
func previousImage(before current: ImageFile) -> ImageFile?
```

#### 4. ImageCanvas (SwiftUI View)
**Responsibilities:**
- Display image with zoom/pan
- Handle gestures (pinch, scroll, drag)
- Center image when fit-to-window
- Maintain aspect ratio

**Modifiers:**
- `.gesture(MagnificationGesture())` - Pinch zoom
- `.gesture(DragGesture())` - Pan when zoomed
- `.onScroll()` - Scroll wheel zoom

---

## Data Models

### ImageFile
```swift
struct ImageFile: Identifiable {
    let id: UUID
    let url: URL
    let filename: String
    let fileSize: Int64
    var dimensions: CGSize?
    let createdDate: Date
}
```

### ZoomState
```swift
struct ZoomState {
    var scale: CGFloat = 1.0       // 0.1 to 16.0
    var offset: CGSize = .zero     // Pan offset when zoomed
    var mode: ZoomMode = .fitToWindow
    
    enum ZoomMode {
        case fitToWindow
        case actualSize
        case custom
    }
}
```

### ImageMetadata
```swift
struct ImageMetadata {
    let dimensions: CGSize
    let fileSize: Int64
    let colorSpace: String
    let dpi: CGFloat?
    let format: ImageFormat
}

enum ImageFormat: String {
    case jpeg = "JPEG"
    case png = "PNG"
    case heif = "HEIF"
}
```

---

## Performance Requirements

### Loading Performance
| Metric | Target | Measurement |
|--------|--------|-------------|
| Cold start | <1s | Launch to window appears |
| Image load (5MB) | <200ms | URL to display |
| Navigation | <100ms | Key press to new image |
| Zoom response | <16ms | Gesture to render |

### Memory Management
- **Cache Strategy:** LRU cache for 3 images (current, prev, next)
- **Max Memory:** 500MB for cached images
- **Large Images:** Load downsampled version first, then full res
- **Background Images:** Preload next/prev in background

---

## File Format Support

### Phase 1 Supported Formats
- **JPEG/JPG** - via ImageIO
- **PNG** - via ImageIO
- **HEIF/HEIC** - via ImageIO (macOS native)

### Phase 2 Consideration
- GIF (static first frame)
- WebP
- TIFF
- BMP
- RAW formats (CR2, NEF, ARW)

---

## Error Handling

### Error Scenarios
1. **File not found** → Show alert: "Image file no longer exists"
2. **Unsupported format** → Show alert: "Format not supported: {ext}"
3. **Corrupted file** → Show alert: "Unable to open image: file may be corrupted"
4. **Permission denied** → Show alert: "No permission to access file"
5. **Memory limit** → Downsample image, show warning

### Error UI
- Native macOS alert dialogs
- Non-blocking for navigation errors (show in info bar)
- Log errors for debugging

---

## Testing Strategy

### Unit Tests
- `FileNavigator`: Folder scanning, sorting, navigation
- `ImageLoader`: Format detection, metadata extraction
- `ZoomState`: Zoom calculations, bounds checking
- `ImageFile`: Model creation, URL handling

### Integration Tests
- Open image → verify metadata displayed
- Navigate → verify correct image loads
- Zoom → verify scale applied correctly

### Manual Testing Checklist
- [ ] Open JPEG, PNG, HEIF files
- [ ] Drag & drop onto dock icon
- [ ] Navigate with keyboard in folder with 10+ images
- [ ] Zoom in/out with scroll and pinch
- [ ] Pan while zoomed in
- [ ] Toggle info bar
- [ ] Resize window (image scales appropriately)
- [ ] Light/dark mode switching
- [ ] Open corrupted file (shows error)
- [ ] Large image (>50MB) loads efficiently

---

## Success Metrics

### Phase 1 Complete When:
- [ ] All user stories pass acceptance criteria
- [ ] All manual tests pass
- [ ] Performance targets met
- [ ] App runs on macOS 13+
- [ ] No critical bugs
- [ ] Basic help documentation complete

### User Validation:
- Can open any JPEG/PNG/HEIF image in <1s
- Intuitive enough to use without documentation
- Faster than Preview.app for basic viewing

---

## Timeline Estimate

| Task | Effort | Dependencies |
|------|--------|--------------|
| Project setup | 1 hour | - |
| Core models | 2 hours | Project setup |
| FileNavigator | 3 hours | Core models |
| ImageLoader | 4 hours | Core models |
| ImageCanvas (basic) | 4 hours | ImageLoader |
| ImageViewModel | 3 hours | FileNavigator, ImageLoader |
| Main window UI | 3 hours | ViewModel, Canvas |
| Zoom/Pan gestures | 4 hours | ImageCanvas |
| Info bar | 2 hours | ViewModel |
| Keyboard shortcuts | 2 hours | ViewModel |
| Menu bar | 2 hours | ViewModel |
| Error handling | 2 hours | All components |
| Testing | 4 hours | All components |
| Polish/bug fixes | 4 hours | Testing |

**Total:** ~40 hours (~1 week full-time)

---

## Future Considerations (Phase 2+)

### Features to Design For:
- Thumbnail grid → Keep `ImageFile` model extensible
- EXIF editing → Store metadata in model
- Folder watching → Use FileMonitor service
- Slideshow → Timer + auto-navigate

### Architecture Notes:
- Keep ViewModels UI-agnostic for future iPad version
- Use protocol-based services for testability
- Consider Core Data for image database (later phases)

---

## Open Questions

1. **Window restoration:** Should app remember last opened image?
   - *Decision needed:* Yes/No/User preference
   
2. **Multiple windows:** Allow opening multiple images simultaneously?
   - *Recommendation:* Yes (Phase 1), standard macOS behavior
   
3. **Thumbnail generation:** Generate on-demand or cache to disk?
   - *Recommendation:* Memory-only cache for Phase 1
   
4. **App icon:** Simple or detailed?
   - *Recommendation:* Minimal icon (photo frame or aperture)

---

## Approval

- [ ] Requirements approved by PM
- [ ] Design approved by PM
- [ ] Technical approach approved
- [ ] Ready to begin implementation

**Next Steps:**
1. Create Xcode project
2. Implement core models
3. Build FileNavigator service
4. Develop ImageLoader service
5. Create SwiftUI views

