# Getting Started with macOS Development

## 🎯 For Experienced Engineers New to macOS

Welcome! Here's what's different about macOS development:

### The Ecosystem

| Concept | macOS Equivalent | Similar To |
|---------|------------------|------------|
| Build tool | Xcode / xcodebuild | Visual Studio / MSBuild |
| Package manager | Swift Package Manager | npm / cargo / go mod |
| Project file | `.xcodeproj` | `.sln` / `.csproj` |
| IDE | Xcode | Visual Studio / IntelliJ |
| Debugger | LLDB (in Xcode) | GDB / Visual Studio Debugger |

### Quick Start (5 minutes)

```bash
# 1. Build and run (creates project if needed)
make run

# 2. Or manually with Xcode
make open          # Opens Xcode GUI
# Then press ⌘R in Xcode to run with debugger
```

---

## 🛠️ Development Workflow

### Option 1: Command Line (Fast iteration)

```bash
# One-time setup
make setup         # Creates Xcode project

# Development cycle
make build         # Compile
make run           # Run the app
make test          # Run unit tests
make clean         # Clean build artifacts
```

### Option 2: Xcode GUI (Best for debugging)

```bash
make open          # Opens Xcode
```

**In Xcode:**
- `⌘R` - Build and run
- `⌘B` - Build only
- `⌘U` - Run tests
- `⌘.` - Stop running app
- `⌘K` - Clean build folder

---

## 🐛 Debugging

### Command Line Debugging (LLDB)

```bash
# Build with debug symbols
make build

# Run app manually
open build/Debug/SIV.app

# Attach debugger to running process
lldb -p $(pgrep SIV)
```

### Xcode Debugging (Recommended)

**Much better experience than CLI!**

```bash
make debug         # Opens Xcode with debugger ready
```

**In Xcode:**
1. Click line numbers to set breakpoints
2. Press `⌘R` to run with debugger attached
3. When breakpoint hits:
   - `po variable` - Print object
   - Step over: `F6`
   - Step into: `F7`
   - Continue: `⌃⌘Y`

**Debug Console:**
- View → Debug Area → Show Debug Area
- Print statements appear here
- Can execute Swift code directly

---

## 📁 Project Structure

```
SIV.xcodeproj/          # Xcode project (created by make setup)
├── project.pbxproj     # Project configuration
└── ...

SIV/                    # Source code
├── App/                # Entry point
├── Views/              # UI components
├── ViewModels/         # Business logic
├── Models/             # Data structures
└── Services/           # Utilities

build/                  # Build output (created by xcodebuild)
├── Debug/              
│   └── SIV.app        # Runnable application
└── Release/
    └── SIV.app        # Optimized build
```

---

## 🔨 Build System Deep Dive

### Makefile Targets

```bash
make help           # Show all available commands
make setup          # One-time project setup
make build          # Compile (Debug mode)
make run            # Compile + run
make test           # Run unit tests
make clean          # Remove build artifacts
make open           # Open in Xcode
make release        # Build optimized version
make install        # Copy to /Applications
```

### Manual Commands (if Makefile issues)

```bash
# Build
xcodebuild -project SIV.xcodeproj \
           -scheme SIV \
           -configuration Debug \
           build

# Run
open build/Debug/SIV.app

# Test
xcodebuild test -project SIV.xcodeproj \
                -scheme SIV \
                -destination 'platform=macOS'

# Clean
xcodebuild clean -project SIV.xcodeproj -scheme SIV
```

---

## 🎓 Key Concepts for macOS Development

### 1. App Bundle (.app)

Unlike executables on Linux/Windows, macOS apps are **bundles** (folders that look like files):

```
SIV.app/
├── Contents/
│   ├── MacOS/
│   │   └── SIV              # Actual executable
│   ├── Resources/           # Images, assets
│   ├── Info.plist           # App metadata
│   └── _CodeSignature/      # Code signing
```

Run with: `open SIV.app` (not `./SIV.app`)

### 2. SwiftUI Previews

In Xcode, SwiftUI files show live previews:

```swift
#Preview {
    ImageCanvas()
}
```

Press `⌥⌘P` in Xcode to show/hide preview pane.

### 3. Build Configurations

- **Debug**: Fast compilation, includes debug symbols
- **Release**: Optimized, stripped symbols, smaller binary

```bash
make build     # Debug
make release   # Release
```

### 4. Signing & Entitlements

macOS apps must be **code signed**. For development:
- Xcode auto-signs with your Apple ID
- No App Store account needed for local development

---

## 🚀 First Run Instructions

### Prerequisites

1. **Install Xcode** (if not already):
   ```bash
   xcode-select --install          # Command line tools
   # OR install full Xcode from App Store
   ```

2. **Verify installation**:
   ```bash
   xcodebuild -version
   # Should show: Xcode 15.x
   ```

### Quick Start

```bash
# 1. Create Xcode project
./scripts/create_xcode_project.sh

# 2. Build and run
make run

# 3. Test it!
# - Drag an image onto the window
# - Press arrow keys to navigate
# - Scroll to zoom
```

### If Manual Setup Needed

If automated setup fails:

```bash
# 1. Open Xcode
open -a Xcode

# 2. Create new project:
#    File → New → Project → macOS → App
#    Name: SIV
#    Interface: SwiftUI
#    Save to: /Users/klastochkin/prj/siv

# 3. Delete default ContentView.swift

# 4. Add source files:
#    Right-click project → Add Files
#    Select SIV/ folder
#    ✓ Create groups
#    ✓ Add to target: SIV

# 5. Press ⌘R to build and run
```

---

## 💡 Development Tips

### Hot Reload

SwiftUI has live preview, but not hot reload for running app:
- Change code → `⌘R` to rebuild
- Or use SwiftUI previews (⌥⌘P in Xcode)

### Logging

```swift
// These print to Xcode console
print("Debug: \(value)")
NSLog("System log: %@", message)
os_log("Proper logging", type: .debug)
```

View logs:
- Xcode: Debug Area (⇧⌘Y)
- Console.app: Shows all system logs

### Performance Profiling

```bash
# In Xcode: Product → Profile (⌘I)
# Opens Instruments - powerful profiling tool
```

Tools available:
- Time Profiler (CPU usage)
- Leaks (memory leaks)
- Allocations (memory usage)

### Common Issues

**Issue: "No such module 'SwiftUI'"**
- Fix: Clean build folder (`⌘K` in Xcode)

**Issue: "Code signing failed"**
- Fix: Xcode → Preferences → Accounts → Add Apple ID

**Issue: "Unable to run app"**
- Fix: Check build/Debug/ for SIV.app
- Try: `open build/Debug/SIV.app` manually

---

## 📝 Cheat Sheet

```bash
# Essential commands
make run            # Build and run
make open           # Open in Xcode
make test           # Run tests
make clean          # Clean build

# Xcode shortcuts
⌘R                  # Run
⌘B                  # Build
⌘U                  # Test
⌘.                  # Stop
⌘K                  # Clean
⇧⌘Y                 # Toggle debug area
⌥⌘P                 # Toggle preview
```

---

## 🎯 Recommended Workflow

**For quick iterations:**
```bash
# Terminal window 1
make run
# Edit code in Cursor/VS Code
# Ctrl+C to stop
# make run again
```

**For debugging:**
```bash
make open           # Opens Xcode
# Set breakpoints in Xcode
# Press ⌘R
# Debug in Xcode GUI
```

**For testing:**
```bash
make test           # Run all tests
# Or in Xcode: ⌘U
```

---

## 🔗 Resources

**Official:**
- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Xcode Help](https://developer.apple.com/xcode/)

**Community:**
- [Hacking with Swift](https://www.hackingwithswift.com/)
- [Swift by Sundell](https://www.swiftbysundell.com/)
- [objc.io](https://www.objc.io/)

---

## ✅ Verify Setup

Run this to check everything works:

```bash
# Should all pass
xcodebuild -version                    # Xcode installed?
make setup                             # Project created?
make build                             # Compiles?
make test                              # Tests run?
make run                               # App launches?
```

Success = You see the SIV window open! 🎉

---

**Need help?** Check docs/quick-start.md for troubleshooting.

