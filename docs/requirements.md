# Product Requirements - SIV (Simple Image Viewer)

## Phase 1 - Single Image Viewer (MVP)

This version supports viewing a single image: displaying, scaling, and panning around zoomed images.

### File Operations
- [x] Open image files (JPEG, PNG, HEIF) - **DONE**
- [x] Drag & drop support - **DONE**
- [x] Keyboard shortcut: Cmd+O - **DONE** (NSOpenPanel)

### Image Display
- [x] Display image in window - **DONE**
- [x] Center image, maintain aspect ratio - **DONE**
- [x] Fit to window by default - **DONE** (scales up small images, down large)
- [x] Support light/dark mode - **DONE**

### Zoom & Pan
- [x] Scroll wheel zoom - **DONE** (0.001 sensitivity)
- [x] Trackpad pinch gesture - **DONE** (0.2 dampening, smooth)
- [x] Keyboard shortcuts (Cmd+/-, Cmd+0, Cmd+1) - **DONE**
- [x] Zoom range: 10% to 1600% - **DONE** (hard limits enforced)
- [x] Pan with arrow keys (↑↓←→) - **DONE** (50px per key press)
- [x] Pan with 2-finger drag on trackpad - **DONE**
- [x] Pan enabled when image larger than window - **DONE**

### Navigation Between Images
- [ ] Navigate to next/previous image - **NOT IN PHASE 1**
  - Note: Navigation is a Phase 2 feature (albums)
  - Future: Use Cmd+←/Cmd+→ or menu items for navigation
- [ ] Space bar for next image - **NOT IN PHASE 1**
- [ ] Auto-scan folder for all images - **NOT IN PHASE 1**
- [ ] Wrap around (last → first) - **NOT IN PHASE 1**

### Image Information
- [x] Show filename, resolution, file size - **DONE**
- [x] Show current zoom level - **DONE** (accurate percentage)
- [x] Toggle info bar with "I" key - **DONE**
- [x] Bottom overlay bar (non-intrusive) - **DONE**

### Window Management
- [x] Minimum window size: 400x300 - **DONE**
- [x] Multiple windows support - **DONE**
- [x] Standard macOS window controls - **DONE**

### Error Handling
- [x] Graceful handling of corrupted files - **DONE** (basic)
- [x] Error messages for unsupported formats - **DONE**
- [x] Permission denied errors - **DONE**
- [x] File not found errors - **DONE**

## Phase 2 - Picture Albums (MVP)

### Picture Album requirements

This phase introduces Picture Albums and image navigation. Phase 2 supports ONE single album ("default").
The Picture Album is represented internally as a list of files. The files are not moved when added to/removed from album, only list of files is modified.
Album is stored in file, it's json formatted file.
Album files has extension .sivalb
Default album is the only album supported in phase 2. It's stored at: `~/Library/Application Support/SIV/default.sivalb`

**Album View:**
- Album is displayed in the view inside SIV window
- Toggle between Album View and Image View via menu: View → Toggle Album/Image View
- Album View supports 2 representations:
  - Thumbnails (similar to macOS Icon view)
  - List (similar to macOS List view)
- Missing files: Display red X icon overlay on thumbnail/list item

**Album Loading:**
- When app starts, Default album is automatically loaded
- Future app versions might need to open last used album - design accordingly
- If during album opening file(s) are not found, show summary dialog with list of missing files
- Dialog includes "Remove All Missing Files" button

**Adding Files to Album:**
- Menu: File → Add to Album (supports multiple file selection)
- Drag & Drop: Files dropped into Album View are added to album

### Image View requirements update

**Image View (Phase 1 features):**
- Image View is implemented in phase 1
- When file is opened via File → Open menu, it's opened in Image View
- Opening file does not affect Albums - file is not added to album by default
- Currently opened file can be added to currently opened album:
  - Keyboard shortcut: Cmd+A
  - Context menu: Right-click → Add to Album
- Drag & Drop: Only single file supported to be dropped in Image View

**Album → Image View Integration:**
- When user selects image in Album View, it's displayed in Image View
- Navigation between images in album using arrow keys, space bar
- Image loading is asynchronous - does not block album navigation
- If user selects another image while previous is still loading, previous load is cancelled and new load starts

### Thumbnail View
- [ ] Thumbnail grid view
- [ ] Grid size adjustment

### EXIF Management
- [ ] View EXIF data

### Advanced Features
- [ ] Folder watching (auto-reload)

## Phase 3 - Enhanced Features

TBD

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