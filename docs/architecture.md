# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      SwiftUI Views                      │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐   │
│  │ImageViewer   │  │ImageCanvas  │  │  InfoBar     │   │
│  │   Window     │  │ (Zoomable)  │  │ (Metadata)   │   │
│  └──────┬───────┘  └──────┬──────┘  └──────┬───────┘   │
│         │                 │                │           │
│         └─────────────────┼────────────────┘           │
│                           │                            │
└───────────────────────────┼────────────────────────────┘
                            │
                   ┌────────▼─────────┐
                   │  ImageViewModel  │ ← ObservableObject
                   │  @Published vars │
                   └────────┬─────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
      ┌─────▼──────┐  ┌─────▼──────┐  ┌────▼─────┐
      │ImageLoader │  │   File     │  │  Image   │
      │  Service   │  │ Navigator  │  │  Cache   │
      └─────┬──────┘  └─────┬──────┘  └────┬─────┘
            │               │               │
            └───────────────┼───────────────┘
                            │
                   ┌────────▼─────────┐
                   │   Core Models    │
                   │  ImageFile       │
                   │  ZoomState       │
                   │  ImageMetadata   │
                   └──────────────────┘
```

## MVVM Pattern

### Views (SwiftUI)
- **ImageViewerWindow**: Main container window, handles drag & drop
- **ImageCanvas**: Displays image with zoom/pan gestures
- **InfoBar**: Shows metadata in bottom overlay

### ViewModel
- **ImageViewModel**: 
  - Central state management
  - Orchestrates services
  - Exposes UI state via `@Published` properties
  - Handles user actions (navigation, zoom)

### Models
- **ImageFile**: Represents an image file with metadata
- **ZoomState**: Tracks zoom level and pan offset
- **ImageMetadata**: Extracted image properties

### Services
- **ImageLoader**: Async image loading and decoding
- **FileNavigator**: Folder scanning and navigation logic
- **ImageCache**: LRU cache for performance optimization

## Data Flow

### Opening an Image

```
User Action (Drag & Drop / ⌘O)
    ↓
ImageViewerWindow.handleDrop()
    ↓
ImageViewModel.openImage(url:)
    ↓
┌───────────────────────────────────┐
│  ImageLoader.loadImage()          │ → Load NSImage
│  FileNavigator.getImagesInFolder()│ → Scan folder
│  ImageCache.set()                 │ → Cache image
└───────────────────────────────────┘
    ↓
Update @Published properties
    ↓
SwiftUI View Updates (automatic)
```

### Navigating Between Images

```
User Action (→ key / Space)
    ↓
NotificationCenter → ImageViewModel
    ↓
ImageViewModel.navigateNext()
    ↓
FileNavigator.nextImage()
    ↓
Check ImageCache
    ├─ Hit: Return cached image
    └─ Miss: ImageLoader.loadImage()
    ↓
Update @Published properties
    ↓
SwiftUI View Updates
    ↓
Background: Preload adjacent images
```

### Zooming

```
User Gesture (Pinch / Scroll)
    ↓
ImageCanvas gesture handler
    ↓
ImageViewModel.zoom()
    ↓
Update ZoomState (scale, offset)
    ↓
SwiftUI re-renders with new scale
```

## Concurrency Model

### Main Actor (@MainActor)
- `ImageViewModel`: All UI state updates
- SwiftUI Views: Automatic main thread execution

### Background Tasks
- Image loading: `DispatchQueue.global(qos: .userInitiated)`
- Preloading adjacent images: `Task.detached(priority: .background)`
- Cache operations: Thread-safe with `NSLock`

### Async/Await
- `ImageLoader.loadImage()`: Uses Swift concurrency
- Error handling: Structured try/catch with typed errors

## Memory Management

### Image Caching Strategy

```
┌──────────────────────────────────────┐
│         ImageCache (LRU)             │
│  Max: 500 MB                         │
│                                      │
│  [Current] [Previous] [Next]         │
│     ↑          ↑         ↑           │
│  Always    Preloaded  Preloaded      │
│  in cache  in cache   in cache       │
└──────────────────────────────────────┘

On cache overflow:
  → Evict least recently used images
  → Keep current + adjacent images

Preloading:
  → Background priority
  → Only if not already cached
  → Limited to ±1 image from current
```

## Error Handling

### Error Types
```
ImageLoadError
├── fileNotFound        → Alert dialog
├── unsupportedFormat   → Alert dialog
├── corruptedFile       → Alert dialog
├── permissionDenied    → Alert dialog
└── unknownError        → Alert with details

NavigationError
├── folderNotAccessible → Show in info bar
└── noImagesFound       → Show in info bar
```

### Error Propagation
1. Service throws typed error
2. ViewModel catches and converts to user message
3. View displays via `errorMessage` binding
4. Non-critical errors shown in info bar
5. Critical errors shown as alert dialogs

## Testing Strategy

### Unit Tests
- **Models**: ZoomState calculations, ImageFile creation
- **Services**: FileNavigator logic, cache eviction
- **ViewModels**: State management, navigation logic

### Integration Tests
- Image loading pipeline
- Navigation flow
- Cache behavior under load

### Manual Testing
- Gesture recognition
- Performance benchmarks
- UI/UX validation
- Cross-format compatibility

## Performance Optimizations

1. **Lazy Loading**: Images loaded on-demand
2. **Preloading**: Adjacent images loaded in background
3. **LRU Cache**: Minimizes disk I/O
4. **Async Operations**: Non-blocking UI
5. **SwiftUI**: Automatic view diffing and updates
6. **Memory Bounds**: 500MB cache limit prevents bloat

## Extensibility Points

### Adding New Features

**Thumbnail View (Phase 2)**:
- Add `ThumbnailGridView` in Views/
- Extend `ImageViewModel` with grid state
- Reuse `FileNavigator` and `ImageCache`

**EXIF Editing (Phase 2)**:
- Add `EXIFService` in Services/
- Extend `ImageMetadata` model
- Add `EXIFEditorView` in Views/

**New Image Formats**:
- Update `ImageFormat` enum
- No other changes needed (ImageIO handles most formats)

## Dependencies

### System Frameworks
- **SwiftUI**: UI framework
- **AppKit**: macOS windowing (NSImage, NSApplication)
- **ImageIO**: Image decoding
- **CoreGraphics**: Image manipulation
- **Foundation**: Core utilities

### No External Dependencies
- Pure Swift/macOS solution
- No package managers required
- Minimal attack surface
- Fast build times

## Platform Requirements

- **macOS**: 13.0+ (Ventura)
- **Swift**: 5.9+
- **Xcode**: 15.0+
- **Architecture**: Apple Silicon + Intel (universal binary)

