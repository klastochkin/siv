# macOS Application Architecture Guide

This guide explains macOS application architecture for developers coming from Windows/MFC background.

## Table of Contents
1. [Architecture Patterns](#architecture-patterns)
2. [Input Event Routing (Responder Chain)](#input-event-routing-responder-chain)
3. [Rendering Pipeline](#rendering-pipeline)
4. [UI Element Ownership](#ui-element-ownership)
5. [Comparison with MFC](#comparison-with-mfc)

---

## Architecture Patterns

### Model-View-Controller (MVC) - Traditional macOS

In traditional macOS (AppKit), the pattern is **MVC**:

```
┌─────────┐      ┌──────────┐      ┌─────────┐
│  Model  │◄─────┤  View    │      │Controller│
│ (Data)  │      │ (UI)     │─────►│ (Logic)  │
└─────────┘      └──────────┘      └─────────┘
     ▲                │                  │
     └────────────────┴──────────────────┘
```

**Model**: Your data structures (like `ImageFile`, `ZoomState`)
- Pure data, no UI knowledge
- Similar to MFC's document data

**View**: UI elements (NSView, NSButton, etc.)
- Displays data, handles drawing
- Similar to MFC's CView

**Controller**: Mediates between Model and View
- Handles user input, updates model, updates view
- Similar to MFC's CDocument + CView together

### Model-View-ViewModel (MVVM) - SwiftUI

SwiftUI uses **MVVM** pattern:

```
┌─────────┐      ┌──────────────┐      ┌─────────┐
│  Model  │      │ ViewModel    │      │  View   │
│ (Data)  │◄─────┤ (State/Obs)  │─────►│ (SwiftUI)│
└─────────┘      └──────────────┘      └─────────┘
```

**Model**: Same as MVC - pure data
- `ImageFile`, `ZoomState` classes

**ViewModel**: Observable state container
- `@ObservableObject` or `@StateObject` classes
- Contains `@Published` properties that trigger view updates
- Similar to MFC's document, but reactive

**View**: Declarative SwiftUI views
- Automatically updates when ViewModel changes
- No manual update code needed (unlike MFC's `InvalidateRect`)

### Example from Your Code

```swift
// MODEL - Pure data
class ZoomState: ObservableObject {
    @Published var scale: CGFloat = 1.0  // When this changes, views update
    @Published var offset: CGSize = .zero
}

// VIEWMODEL - State management
class ImageViewModel: ObservableObject {
    @Published var currentImage: NSImage?
    @Published var zoomState = ZoomState()  // Nested observable
}

// VIEW - Declarative UI
struct ImageCanvas: View {
    @ObservedObject var viewModel: ImageViewModel  // Observes changes
    
    var body: some View {
        Image(nsImage: viewModel.currentImage)  // Auto-updates when currentImage changes
            .frame(width: viewModel.zoomState.scale * 100)  // Auto-updates when scale changes
    }
}
```

**Key Difference from MFC**: 
- MFC: You call `InvalidateRect()` → `OnDraw()` → manually update UI
- SwiftUI: Change `@Published` property → view automatically re-renders

---

## Input Event Routing (Responder Chain)

### The Responder Chain

macOS uses a **responder chain** to route events. This is fundamentally different from MFC's message map.

```
Event (keyboard/mouse) → Window → First Responder → Next Responder → ... → Application
```

**First Responder**: The view that currently has focus (receives keyboard events)

**Responder Chain**: A linked list of objects that can handle events:
1. First Responder (e.g., a text field)
2. First Responder's superview
3. Window's content view
4. Window
5. Window's delegate
6. Application
7. Application delegate

### How Events Flow

```
User presses key
    ↓
NSWindow receives NSEvent
    ↓
Window finds first responder (NSView)
    ↓
Calls keyDown(with:) on first responder
    ↓
If not handled, calls keyDown on next responder (superview)
    ↓
Continues up chain until handled or reaches Application
```

### Example: Arrow Keys in Your App

```swift
// In SwiftUI, keyboard shortcuts use the responder chain
Button("") { 
    imageViewModel.panLeft() 
}
.keyboardShortcut(.leftArrow, modifiers: [])
```

**What happens**:
1. User presses Left Arrow
2. Event goes to first responder (the Button's underlying NSButton)
3. NSButton checks if it has a keyboard shortcut for Left Arrow
4. If yes, calls the button's action
5. If no, passes to next responder

**Problem with Arrow Keys**: 
- Arrow keys without modifiers often go to the terminal (when running from terminal)
- Terminal captures them before they reach your app
- Solution: Make window key and set proper first responder

### MFC Comparison

**MFC Message Routing**:
```cpp
BEGIN_MESSAGE_MAP(CMyView, CView)
    ON_WM_KEYDOWN()
    ON_COMMAND(ID_ZOOM_IN, OnZoomIn)
END_MESSAGE_MAP()

void CMyView::OnKeyDown(UINT nChar, UINT nRepCnt, UINT nFlags) {
    if (nChar == VK_LEFT) {
        PanLeft();
    }
}
```

**macOS Responder Chain**:
```swift
override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 123: // Left arrow
        panLeft()
    default:
        super.keyDown(with: event)  // Pass to next responder
    }
}
```

**Key Difference**:
- MFC: Message map routes to specific handler
- macOS: Event bubbles up responder chain until handled

---

## Rendering Pipeline

### AppKit (Traditional macOS)

**Immediate Mode Drawing** (like MFC's OnDraw):

```swift
class MyView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // Called when view needs redrawing
        let path = NSBezierPath(rect: bounds)
        NSColor.blue.setFill()
        path.fill()
    }
}

// Trigger redraw
view.needsDisplay = true  // Like InvalidateRect() in MFC
```

**Rendering Flow**:
1. View marked as needing display (`needsDisplay = true`)
2. AppKit schedules draw call
3. `draw(_:)` called on next render cycle
4. Core Graphics renders to backing store
5. Compositor displays on screen

### SwiftUI (Modern macOS)

**Declarative Rendering** (automatic):

```swift
struct MyView: View {
    @State var color: Color = .blue  // State change triggers re-render
    
    var body: some View {
        Rectangle()
            .fill(color)  // Automatically re-renders when color changes
    }
}
```

**Rendering Flow**:
1. State changes (`@Published` or `@State` property)
2. SwiftUI detects change
3. Recomputes `body` (view tree)
4. Diffs with previous tree
5. Only re-renders changed parts
6. Metal/Core Animation renders efficiently

**Key Difference from MFC**:
- MFC: You control when to draw (`InvalidateRect` → `OnDraw`)
- SwiftUI: Framework automatically re-renders when state changes

### View Update Cycle

```swift
// 1. User action or data change
viewModel.zoomState.scale = 2.0  // @Published property changes

// 2. SwiftUI detects change (via Combine framework)
// ObservableObject publishes change

// 3. Views observing this object get notified
@ObservedObject var viewModel: ImageViewModel  // Receives notification

// 4. SwiftUI re-evaluates body
var body: some View {
    Image(...)
        .frame(width: viewModel.zoomState.scale * 100)  // New value used
}

// 5. Diffing engine compares old vs new view tree
// Only changed parts re-render

// 6. Core Animation/Metal renders efficiently
```

---

## UI Element Ownership

### AppKit (Traditional) - Reference Counting

**Ownership Model**: Strong references, manual memory management (or ARC)

```swift
class MyWindowController: NSWindowController {
    var myView: NSView?  // Strong reference - owns the view
    
    override func windowDidLoad() {
        super.windowDidLoad()
        myView = MyCustomView()  // Created, retained
        window?.contentView?.addSubview(myView!)  // View hierarchy retains it too
    }
}
```

**View Hierarchy**:
```
NSWindow (owns)
  └─ contentView: NSView (owns)
      └─ subviews: [NSView] (each retained by parent)
          └─ subviews: [NSView] (recursive)
```

**Key Points**:
- Parent view **owns** child views (strong reference)
- Removing from superview releases the view
- Similar to MFC's parent-child window relationship

### SwiftUI - Value Types + Automatic Management

**Ownership Model**: Value types, framework manages lifecycle

```swift
struct MyView: View {
    var body: some View {
        VStack {  // Value type - copied, not referenced
            Text("Hello")  // Value type
            Button("Click") { }  // Value type
        }
    }
}
```

**View Hierarchy** (conceptual):
```
View (value type)
  └─ body: some View (value type)
      └─ VStack (value type)
          └─ children: [View] (array of value types)
```

**Key Points**:
- Views are **value types** (structs), not reference types
- SwiftUI framework manages actual NSView instances internally
- Framework creates/destroys underlying AppKit views as needed
- You don't manage memory - framework does it

**Lifecycle**:
```swift
struct ImageCanvas: View {
    @ObservedObject var viewModel: ImageViewModel
    
    var body: some View {
        Image(...)
            .onAppear {
                // Called when view appears on screen
                // Framework created underlying NSView
            }
            .onDisappear {
                // Called when view removed
                // Framework will destroy underlying NSView
            }
    }
}
```

### Comparison with MFC

**MFC Ownership**:
```cpp
class CMyView : public CView {
    CButton* m_pButton;  // Raw pointer - you manage lifetime
    
public:
    void OnCreate() {
        m_pButton = new CButton();
        m_pButton->Create(...);
    }
    
    ~CMyView() {
        delete m_pButton;  // Must manually delete
    }
};
```

**SwiftUI Ownership**:
```swift
struct MyView: View {
    var body: some View {
        Button("Click") { }  // Framework manages lifetime
        // No manual cleanup needed
    }
}
```

---

## Comparison with MFC

### Event Handling

| MFC | macOS AppKit | SwiftUI |
|-----|--------------|---------|
| `BEGIN_MESSAGE_MAP` | `keyDown(with:)` in responder | `.keyboardShortcut()` |
| `ON_WM_KEYDOWN` | Override `keyDown` | Button with shortcut |
| `OnKeyDown()` | `func keyDown(with: NSEvent)` | Closure in Button |
| Message routing | Responder chain | Framework handles |

### Rendering

| MFC | macOS AppKit | SwiftUI |
|-----|--------------|---------|
| `OnDraw(CDC*)` | `draw(_ dirtyRect:)` | Declarative `body` |
| `InvalidateRect()` | `needsDisplay = true` | Automatic on state change |
| Manual drawing | Core Graphics | Declarative DSL |
| Immediate mode | Immediate mode | Retained mode (automatic) |

### Memory Management

| MFC | macOS AppKit | SwiftUI |
|-----|--------------|---------|
| `new`/`delete` | ARC (automatic) | Value types (automatic) |
| Manual cleanup | Strong/weak refs | Framework managed |
| Parent owns child | Parent retains child | Framework manages |

### State Management

| MFC | macOS AppKit | SwiftUI |
|-----|--------------|---------|
| Member variables | Properties | `@State`, `@Published` |
| Manual updates | KVO/Notifications | Automatic updates |
| `UpdateAllViews()` | Manual binding | Reactive binding |

---

## Key Concepts Summary

### 1. Responder Chain
- Events bubble up from first responder to application
- Each responder can handle or pass to next
- Similar to MFC's message routing, but more flexible

### 2. Reactive Updates
- Change `@Published` property → view automatically updates
- No manual `InvalidateRect()` needed
- Framework handles diffing and efficient rendering

### 3. Value Types
- SwiftUI views are structs (value types)
- Framework manages underlying AppKit views
- No manual memory management

### 4. Declarative UI
- Describe what you want, not how to draw it
- Framework handles rendering details
- Similar to HTML/CSS, not like MFC's imperative drawing

---

## Practical Tips

### Making Window Receive Keyboard Events

```swift
// In AppDelegate or view
window.makeKeyAndOrderFront(nil)  // Make window key
window.makeFirstResponder(someView)  // Set first responder
NSApplication.shared.activate(ignoringOtherApps: true)  // Activate app
```

### Observing State Changes

```swift
// ViewModel
class MyViewModel: ObservableObject {
    @Published var count = 0  // Changes trigger view updates
}

// View
struct MyView: View {
    @ObservedObject var viewModel: MyViewModel
    
    var body: some View {
        Text("\(viewModel.count)")  // Auto-updates when count changes
    }
}
```

### Handling Events

```swift
// SwiftUI way (preferred)
Button("Click") { handleClick() }
    .keyboardShortcut("c", modifiers: .command)

// AppKit way (when needed)
override func keyDown(with event: NSEvent) {
    if event.keyCode == 123 {  // Left arrow
        handleLeftArrow()
    } else {
        super.keyDown(with: event)  // Pass to next responder
    }
}
```

---

## Further Reading

- [Apple's Responder Chain Documentation](https://developer.apple.com/documentation/appkit/responders_and_the_responder_chain)
- [SwiftUI State Management](https://developer.apple.com/documentation/swiftui/state-and-data-flow)
- [AppKit View Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaViewsGuide/)
