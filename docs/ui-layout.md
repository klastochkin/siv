# UI Layout & Design Specifications

## Window Layout (Annotated)

```
┌─────────────────────────────────────────────────────────────┐
│ ◉◉◉  SIV                                                     │ Traffic lights (macOS native)
├─────────────────────────────────────────────────────────────┤
│ File   View   Window   Help                                 │ ← Menu Bar
│                                                              │   (Native macOS)
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                     [Image Display Area]                     │ ← ImageCanvas
│                                                              │   • Centered
│                    ┌─────────────────┐                       │   • Aspect ratio preserved
│                    │                 │                       │   • Scales to fit by default
│                    │                 │                       │   • Zoomable (10%-1600%)
│                    │   YOUR IMAGE    │                       │   • Pannable when zoomed
│                    │                 │                       │   • Gesture support
│                    │                 │                       │
│                    └─────────────────┘                       │
│                                                              │
│                  20px padding all sides                      │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│ 📄 IMG_1234.jpg • 1920×1080 • 2.4 MB • 125%              │ ← InfoBar (32px height)
└──────────────────────────────────────────────────────────────┘   • Semi-transparent
                                                                   • Toggleable (I key)
                                                                   • System font 12pt
```

## Color Scheme

### Light Mode
```
Background:      #F5F5F5  (System windowBackgroundColor)
Info Bar:        rgba(255, 255, 255, 0.95)
Separator:       #D1D1D6  (System separatorColor)
Text Primary:    #000000  (System labelColor)
Text Secondary:  #8E8E93  (System secondaryLabelColor)
```

### Dark Mode
```
Background:      #1E1E1E  (System windowBackgroundColor)
Info Bar:        rgba(30, 30, 30, 0.95)
Separator:       #38383A  (System separatorColor)
Text Primary:    #FFFFFF  (System labelColor)
Text Secondary:  #98989D  (System secondaryLabelColor)
```

## Typography

### Info Bar
- **Font:** SF Pro Text (System)
- **Size:** 12pt
- **Weight:** 
  - Filename: Medium (500)
  - Metadata: Regular (400)
- **Color:** Secondary label color

### Empty State
- **Icon:** 64pt system icon
- **Title:** 20pt, Title 3
- **Subtitle:** 13pt, Caption

## Component Breakdown

### 1. ImageViewerWindow (Container)
```
┌─────────────────────────────┐
│     VStack(spacing: 0)      │
│  ┌─────────────────────┐    │
│  │   ImageCanvas       │    │  ← Main content
│  │   (fills space)     │    │
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │   InfoBar           │    │  ← Fixed height 32px
│  │   (conditional)     │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

### 2. ImageCanvas (Image Display)
```
GeometryReader
  └─ ZStack
      └─ Image(nsImage)
          • .resizable()
          • .aspectRatio(contentMode: .fit)
          • .scaleEffect(scale)
          • .offset(offset)
          • .gesture(MagnificationGesture)
          • .gesture(DragGesture)
```

### 3. InfoBar (Metadata)
```
HStack
  ├─ Text (formatted metadata)
  │   • Font: .system(size: 12)
  │   • Color: .secondary
  │   • lineLimit: 1
  │   • padding: 12px H, 8px V
  └─ Spacer
```

## States & Variations

### Empty State
```
┌─────────────────────────────────────┐
│                                     │
│            🖼️ (64pt)                │
│                                     │
│     Open an image to get started    │
│                                     │
│      Drag & drop or press ⌘O        │
│                                     │
└─────────────────────────────────────┘
```

### Loading State
```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│          ⏳ ProgressView             │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### Error State
```
┌─────────────────────────────────────┐
│                                     │
│           ⚠️  (48pt)                │
│                                     │
│   Unable to open image: file may    │
│         be corrupted                │
│                                     │
└─────────────────────────────────────┘
```

### Normal State (Image Loaded)
```
┌─────────────────────────────────────┐
│                                     │
│         ┌────────────┐              │
│         │            │              │
│         │   IMAGE    │              │
│         │            │              │
│         └────────────┘              │
│                                     │
├─────────────────────────────────────┤
│ 📄 filename • dims • size • zoom   │
└─────────────────────────────────────┘
```

## Window Specifications

### Dimensions
- **Minimum Size:** 400 × 300 px
- **Default Size:** 800 × 600 px
- **Maximum Size:** Unlimited (constrained by screen)

### Behavior
- **Resizable:** Yes
- **Full Screen:** Supported (⌃⌘F)
- **Multiple Windows:** Supported
- **Title Bar:** Native macOS style
- **Close Button:** Standard (⌘W)

## Menu Bar Structure

```
┌─ File ─────────────┐
│  Open...      ⌘O   │
│  Close Window ⌘W   │
│  ─────────────────  │
│  Quit         ⌘Q   │
└────────────────────┘

┌─ View ─────────────┐
│  Zoom In      ⌘=   │
│  Zoom Out     ⌘-   │
│  Actual Size  ⌘1   │
│  Fit to Window⌘0   │
│  ─────────────────  │
│  Toggle Info   I   │
│  ─────────────────  │
│  Next Image   →    │
│  Previous     ←    │
└────────────────────┘

┌─ Window ───────────┐
│  (Standard items)  │
└────────────────────┘

┌─ Help ─────────────┐
│  SIV Help          │
│  Keyboard Shortcuts│
└────────────────────┘
```

## Interaction States

### Hover (Future Enhancement)
- Could show zoom controls overlay
- Could brighten info bar slightly
- Not implemented in Phase 1

### Focus
- Standard macOS focus ring on window
- No custom focus states needed

### Drag Target
- Window accepts drops when dragging over
- Visual feedback: System default

## Responsive Behavior

### Small Window (<500px width)
- Image scales down
- Info bar text may truncate (...)
- All functionality remains available

### Large Window (>1500px width)
- Image scales up (max 100% unless zoomed)
- Padding increases proportionally
- Info bar stays bottom-aligned

### Aspect Ratios

#### Portrait Image (Height > Width)
```
┌────────────────┐
│                │
│   ┌──────┐     │
│   │      │     │
│   │IMAGE │     │
│   │      │     │
│   │      │     │
│   └──────┘     │
│                │
└────────────────┘
```

#### Landscape Image (Width > Height)
```
┌────────────────┐
│                │
│                │
│ ┌───────────┐  │
│ │  IMAGE    │  │
│ └───────────┘  │
│                │
│                │
└────────────────┘
```

#### Square Image (1:1)
```
┌────────────────┐
│                │
│  ┌──────────┐  │
│  │          │  │
│  │  IMAGE   │  │
│  │          │  │
│  └──────────┘  │
│                │
└────────────────┘
```

## Zoom Behavior

### Fit to Window (Default)
- Scales image to fit
- Maintains aspect ratio
- Never scales above 100%
- Centered in viewport

### Actual Size (⌘1)
- 1:1 pixel ratio
- May exceed window bounds
- Centered, pan to view all

### Custom Zoom
- 10% to 1600% range
- Zooms around cursor position
- Pan with drag when > window size

## Animations (SwiftUI Default)

- **Image transitions:** Fade (200ms)
- **Zoom:** Spring animation
- **Pan:** No animation (follows gesture)
- **Info bar toggle:** Slide + fade (300ms)

## Accessibility

### VoiceOver Support
- Window title announces filename
- Info bar readable
- Keyboard shortcuts announced

### Keyboard Navigation
- All features accessible via keyboard
- No mouse-only actions

### Dynamic Type
- Info bar respects system text size
- 12pt base, scales with accessibility settings

## Performance Considerations

### Rendering
- Hardware-accelerated (Metal)
- 60fps for smooth gestures
- Debounced resize events

### Memory
- One image rendered at a time
- Background images cached but not rendered
- SwiftUI efficient view diffing

## Platform Integration

### Mission Control
- Each window shows in window switcher
- Preview shows current image

### Dock
- Badge: None
- Bounce: On file open error

### Quick Look Integration
- Not implemented (potential Phase 2)

## Summary

This design provides:
- ✅ Clean, minimal interface
- ✅ Native macOS look and feel
- ✅ Intuitive interactions
- ✅ High performance
- ✅ Accessibility support
- ✅ Keyboard-first workflow
- ✅ Responsive to all window sizes
- ✅ Professional polish

