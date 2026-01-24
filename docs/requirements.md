# Product Requirements - SIV (Simple Image Viewer)

### PHASE 1

This is simple image viewing/navigating application for Mac OS used for learning of devlopment of apps with AI assistance.

## Application structure

Application windows contains 2 main views: Image View and Album View. 
They are behaving as 2 seaparte views, the do not overlap. 
Think of it as File Edit View of IDE (Image View) and Project Structure View of IDE (Album View).
User can toggle Views on/off using Menu or Keyboard shortcuts.
User can resize Views relatively to each other inside app window.
Only one view is active at any moment of time, use can switch them using TAB key or clicking a mouse/touchpad.
When the view is active, all keyboard events (arrow keys, etc. are going into that view first).
Some key compbinations, are common for app. For example, Cmd-1 combination is rescaling image to its real size, and it's always directed to the image view. At the same time, Arrow Keys have different meaning in both Album and Image View and they are handled in the active view only.
Application Menu has 2 sub-menus: Image and Album related to the corresponding view.

# Image Vew

Image View is view where current image is rendered for viewing.
This version supports viewing a single image: displaying, scaling, and panning around zoomed images.

### File Operations
- Open image files (JPEG, PNG, HEIF) 
- Drag & drop support 
- Keyboard shortcut: Cmd+O 

### Image Display
- Display image in window
- Center image, maintain aspect ratio 
- Fit to window by default (scales up small images, down large)

### Zoom & Pan
- Scroll wheel zoom (0.001 sensitivity)
- Trackpad pinch gesture (0.2 dampening, smooth)
- Keyboard shortcuts (Cmd+/-, Cmd+0, Cmd+1)
- Zoom range: 10% to 1600% (hard limits enforced)
- Pan with arrow keys (↑↓←→) (50px per key press)
- Pan with 2-finger drag on trackpad 
- Pan enabled when image larger than window 


### Image Information
- Show filename, resolution, file size 
- Show current zoom level (accurate percentage)
- Bottom overlay bar (non-intrusive)

### Window Management
- Minimum window size: 400x300
- Standard macOS window controls


- Picture Albums (MVP)

This chapter introduces Picture Albums and image navigation. Phase 2 supports ONE single album ("default").
The Picture Album is represented internally as a list of files. The files are not moved when added to/removed from album, only list of files is modified.
Album is stored in file, it's json formatted file.
Album files has extension .sivalb
Default album is the only album supported in this phase. It's stored at: `~/Library/Application Support/SIV/default.sivalb`


**Album View:**
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