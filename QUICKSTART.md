# 🚀 Quick Start - For Engineers New to macOS

You're an experienced engineer but new to macOS/Swift. Here's everything you need.

---

## ⚡ TL;DR - Get Running in 2 Minutes

```bash
# 1. One-time setup (creates Xcode project)
make setup

# 2. Build and run
make run

# 3. Open in Xcode for debugging
make open
# Then press ⌘R in Xcode
```

That's it! 🎉

---

## 🎯 What's Different About macOS Development

### Quick Translation Guide

| You Know | macOS Equivalent |
|----------|------------------|
| `gcc` / `make` | `xcodebuild` |
| `.exe` / binary | `.app` bundle (folder) |
| Visual Studio | Xcode |
| GDB | LLDB |
| `./program` | `open Program.app` |
| Solution file (.sln) | Project file (.xcodeproj) |

### Key Concepts

1. **No traditional executables**: Apps are `.app` bundles (folders disguised as files)
2. **Xcode is standard**: Like Visual Studio for Windows
3. **SwiftUI = Declarative UI**: Think React/Flutter, not imperative UI
4. **LLDB debugger**: GDB-like, but for macOS

---

## 📋 Prerequisites

### Check if you have Xcode:
```bash
xcodebuild -version
```

**If not installed:**
```bash
# Option 1: Command line tools only (minimal)
xcode-select --install

# Option 2: Full Xcode (recommended, 15GB)
# Download from App Store: https://apps.apple.com/us/app/xcode/id497799835
```

---

## 🛠️ Build Commands

```bash
# Show all available commands
make help

# Development workflow
make setup          # One-time: Create Xcode project
make build          # Compile (debug mode)
make run            # Build and run the app
make test           # Run unit tests
make clean          # Remove build artifacts

# Advanced
make release        # Build optimized version
make install        # Install to /Applications
make open           # Open in Xcode (best for debugging)
```

---

## 🐛 Debugging Options

### Option 1: Command Line (Quick & Dirty)

```bash
make build
open build/Debug/SIV.app

# Add print statements in code:
print("Debug: \(someVariable)")
# Output appears in Console.app or system logs
```

### Option 2: Xcode GUI (Recommended)

```bash
make open           # Opens Xcode
```

**In Xcode:**
1. Click line numbers to set breakpoints (like Visual Studio)
2. Press `⌘R` to run with debugger attached
3. When stopped at breakpoint:
   - Hover over variables to inspect
   - Type `po variable` in debug console
   - Step over: `F6`, Step into: `F7`, Continue: `⌃⌘Y`

**Debug Console Commands:**
```lldb
(lldb) po viewModel.currentImage        # Print object
(lldb) p viewModel.zoomState.scale      # Print value
(lldb) expr scale = 2.0                 # Modify variable
(lldb) bt                               # Backtrace (stack)
(lldb) continue                         # Resume execution
```

---

## 📁 Understanding the Build Output

```bash
build/
├── Debug/
│   └── SIV.app/                # The "executable" (it's a folder!)
│       ├── Contents/
│       │   ├── MacOS/
│       │   │   └── SIV         # Actual binary
│       │   ├── Resources/      # Assets, images
│       │   ├── Info.plist      # Metadata
│       │   └── _CodeSignature/ # Apple security
```

**To run:**
```bash
open build/Debug/SIV.app       # ← Note: 'open', not './'
```

---

## 🔧 Manual Build (If Makefile Fails)

```bash
# Build
xcodebuild \
  -project SIV.xcodeproj \
  -scheme SIV \
  -configuration Debug \
  build

# Run
open build/Debug/SIV.app

# Test
xcodebuild test \
  -project SIV.xcodeproj \
  -scheme SIV \
  -destination 'platform=macOS'

# Clean
xcodebuild clean -project SIV.xcodeproj -scheme SIV
rm -rf build/ DerivedData/
```

---

## 📝 Xcode Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘R` | Build and Run |
| `⌘B` | Build only |
| `⌘.` | Stop running |
| `⌘U` | Run tests |
| `⌘K` | Clean build |
| `⇧⌘Y` | Toggle debug console |
| `⇧⌘O` | Open quickly (find file) |
| `⌘/` | Comment/uncomment |
| `⌃I` | Re-indent |
| `⌘⇧F` | Find in project |

---

## 🎓 Project Structure Explained

```
siv/
├── Makefile                 ← Your familiar build tool
├── project.yml              ← Xcodegen config (generates .xcodeproj)
├── SIV.xcodeproj/           ← Xcode project (like .sln)
│
├── SIV/                     ← Source code
│   ├── App/                 ← Entry point
│   │   ├── SIVApp.swift    ← main() equivalent
│   │   └── AppDelegate.swift
│   ├── Views/               ← UI (SwiftUI)
│   ├── ViewModels/          ← Business logic (MVVM)
│   ├── Models/              ← Data structures
│   ├── Services/            ← Utilities
│   └── Info.plist           ← App metadata
│
├── SIVTests/                ← Unit tests
│
├── build/                   ← Build output (gitignored)
│   ├── Debug/
│   │   └── SIV.app         ← Runnable app
│   └── Release/
│
└── docs/                    ← Documentation
```

---

## 🚨 Common Issues & Fixes

### Issue: "xcodebuild: command not found"
**Fix:**
```bash
xcode-select --install
```

### Issue: "No such module 'SwiftUI'"
**Fix:**
```bash
make clean
make build
# Or in Xcode: Product → Clean Build Folder (⇧⌘K)
```

### Issue: "Code signing failed"
**Fix:** Open Xcode → Preferences → Accounts → Sign in with Apple ID (free)

### Issue: "Unable to run SIV.app"
**Fix:**
```bash
# Check if it was built
ls -la build/Debug/SIV.app

# Try running directly
open build/Debug/SIV.app

# If file not found, build first
make build
```

### Issue: Can't see print() output
**Fix:** 
- In Xcode: View → Debug Area → Activate Console (⇧⌘Y)
- Or use Console.app (system utility) to see all logs

---

## 💡 Development Tips

### 1. Edit in Your Favorite Editor

```bash
# Edit code in Cursor, VS Code, etc.
cursor .          # or: code .

# Build from terminal
make build

# Or use Xcode for debugging only
make open
```

### 2. Quick Iteration

```bash
# Terminal 1: Keep running
while true; do
  make run
  echo "Crashed or closed. Rebuilding in 2s..."
  sleep 2
done

# Terminal 2: Edit code
# Changes picked up on next iteration
```

### 3. View App While Coding

```bash
# Run app in background
make run &

# Now you can test drag & drop, keyboard shortcuts
# while still using terminal
```

### 4. Testing Specific Features

```bash
# Create test images
mkdir ~/test-images
cp ~/Pictures/*.jpg ~/test-images/

# Drag images onto SIV.app icon or window
```

---

## 📊 Verification Checklist

```bash
# ✓ Xcode installed?
xcodebuild -version

# ✓ Project created?
ls SIV.xcodeproj/project.pbxproj

# ✓ Builds successfully?
make build

# ✓ Tests pass?
make test

# ✓ App runs?
make run
# You should see a window open

# ✓ Can open image?
# Drag a JPEG onto the window
# Should display the image
```

---

## 🎯 Recommended Workflow

**For You (Experienced Engineer):**

```bash
# 1. Initial setup (once)
make setup

# 2. Daily workflow
#    - Edit code in your preferred editor (Cursor/VS Code)
#    - Build from terminal: make build
#    - Run from terminal: make run
#    - Debug in Xcode when needed: make open

# 3. Before committing
make clean
make build
make test
```

**What Most macOS Devs Do:**
- Live in Xcode 90% of the time
- Use Xcode's integrated editor, debugger, profiler
- Command line for automation/CI only

**You Can Do Either!** The Makefile gives you both options.

---

## 🔗 Quick Reference Links

- **Swift Cheat Sheet**: https://www.hackingwithswift.com/quick-start/beginners
- **SwiftUI Cheat Sheet**: https://fuckingswiftui.com/
- **LLDB Commands**: https://lldb.llvm.org/use/map.html
- **Xcode Shortcuts**: https://swifteducation.github.io/assets/pdfs/XcodeKeyboardShortcuts.pdf

---

## 🎉 First Run Success Criteria

After running `make run`, you should see:

1. ✅ A window opens (800×600px)
2. ✅ Shows "Open an image to get started"
3. ✅ You can drag a JPEG onto it
4. ✅ Image displays centered
5. ✅ Bottom bar shows filename, dimensions, size
6. ✅ Arrow keys navigate (if multiple images in folder)
7. ✅ Scroll wheel zooms

**If all ✅ = SUCCESS! You're running!** 🎊

---

## 📞 Need More Help?

1. `docs/getting-started-cli.md` - Detailed CLI guide
2. `docs/setup-guide.md` - Manual Xcode setup
3. `docs/quick-start.md` - Project overview
4. `DELIVERABLES.md` - What was built

Or just run: `make help`

---

**You're ready to go! Start with `make run` and iterate from there.** 🚀

