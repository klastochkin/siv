# Product Requirements - SIV (Simple Image Viewer)

## Phase 1 - Core Viewing (MVP)

### File Operations
- [ ] Open image files (JPEG, PNG, HEIF)
- [ ] Drag & drop support
- [ ] Open with file association
- [ ] Keyboard shortcut: Cmd+O

### Image Display
- [ ] Display image in window
- [ ] Center image, maintain aspect ratio
- [ ] Fit to window by default
- [ ] Support light/dark mode

### Navigation
- [ ] Navigate with arrow keys (←/→)
- [ ] Space bar for next image
- [ ] Auto-scan folder for all images
- [ ] Wrap around (last → first)

### Zoom & Pan
- [ ] Scroll wheel zoom (centered on cursor)
- [ ] Trackpad pinch gesture
- [ ] Keyboard shortcuts (Cmd+/-, Cmd+0, Cmd+1)
- [ ] Pan with drag when zoomed in
- [ ] Zoom range: 10% to 1600%

### Image Information
- [ ] Show filename, resolution, file size
- [ ] Show current zoom level
- [ ] Toggle info bar with "I" key
- [ ] Bottom overlay bar (non-intrusive)

### Window Management
- [ ] Remember window size/position
- [ ] Minimum window size: 400x300
- [ ] Multiple windows support
- [ ] Standard macOS window controls

### Error Handling
- [ ] Graceful handling of corrupted files
- [ ] Error messages for unsupported formats
- [ ] Permission denied errors
- [ ] File not found errors

## Phase 2 - Enhanced Features

### Thumbnail View
- [ ] Thumbnail grid view
- [ ] Quick preview on hover
- [ ] Grid size adjustment

### Basic Editing
- [ ] Rotate (90° increments)
- [ ] Crop tool
- [ ] Save edits

### EXIF Management
- [ ] View EXIF data
- [ ] Edit metadata
- [ ] Remove EXIF data

### Advanced Features
- [ ] Folder watching (auto-reload)
- [ ] Slideshow mode
- [ ] Favorites/ratings
- [ ] Basic filters

## Technical Requirements

### Performance
- macOS 13+ (Ventura) compatibility
- Native Swift/SwiftUI implementation
- Fast startup time (<1s cold start)
- Image loading <200ms (5MB files)
- Navigation response <100ms
- Memory efficient (LRU cache, 500MB limit)

### Code Quality
- Unit test coverage >70%
- SwiftUI best practices
- MVVM architecture
- Protocol-based services

### User Experience
- Native macOS look and feel
- Intuitive, distraction-free UI
- Keyboard-driven workflow
- Responsive to gestures