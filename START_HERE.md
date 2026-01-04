# 🎯 FOR YOU: Getting Started (No Swift/macOS Experience)

**Status:** You have Xcode Command Line Tools, but not full Xcode.

---

## ⚡ Fastest Path to Running App

### Option 1: Quick & Simple (No Xcode GUI)

```bash
# 1. Install full Xcode (one-time, 15GB, ~30 min download)
# Open App Store and search "Xcode", or:
open "https://apps.apple.com/us/app/xcode/id497799835"

# After Xcode installs:
sudo xcode-select --switch /Applications/Xcode.app
sudo xcodebuild -license accept

# 2. Install xcodegen (makes project setup automatic)
brew install xcodegen
# If brew not installed: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. Run the automated setup
./scripts/install.sh

# 4. Build and run!
make run
```

### Option 2: Manual Setup (If automated fails)

```bash
# 1. Open Xcode (after installing from App Store)
open -a Xcode

# 2. In Xcode: File → New → Project
#    - Choose: macOS → App
#    - Product Name: SIV
#    - Interface: SwiftUI
#    - Language: Swift
#    - Save to: /Users/klastochkin/prj/siv (THIS DIRECTORY)

# 3. In Xcode, delete the default "ContentView.swift" file

# 4. Add your source code:
#    - Right-click on "SIV" in left sidebar
#    - Choose "Add Files to SIV..."
#    - Select the "SIV" folder (the one with App/, Models/, etc.)
#    - Check "Create groups"
#    - Check "SIV" target
#    - Click "Add"

# 5. Add test files:
#    - Right-click on "SIVTests" in left sidebar
#    - Choose "Add Files to SIV..."
#    - Select the "SIVTests" folder
#    - Check "SIVTests" target
#    - Click "Add"

# 6. Press ⌘R to build and run!
```

---

## 🎓 What You Need to Know

### macOS Development is Different

**Unlike Linux/Windows:**
- No `gcc` or traditional `make` workflow
- Apps are **bundles** (folders, not single executables)
- Use `open MyApp.app` instead of `./myapp`
- Xcode is the standard IDE (like Visual Studio)

**Your Background:**
- ✅ You know software engineering → Easy
- ✅ You understand MVC/MVVM → Our code uses MVVM
- ❌ You don't know Swift → That's fine, it's similar to Kotlin/TypeScript
- ❌ You don't know macOS dev → That's what this guide is for!

### Swift in 30 Seconds

```swift
// Variables
let constant = "immutable"          // Like const
var variable = "mutable"            // Like let

// Functions
func greet(name: String) -> String {
    return "Hello, \(name)"         // String interpolation
}

// Classes
class MyClass {
    var property: String = "value"
    
    func method() {
        print(property)
    }
}

// Optional types (can be nil)
var maybeString: String? = nil
if let actualString = maybeString {  // Unwrap optional
    print(actualString)
}

// Async/await (like JavaScript/C#)
func loadData() async throws -> Data {
    let data = try await URLSession.shared.data(from: url)
    return data.0
}
```

**That's 90% of what you need!** The rest you'll pick up from context.

---

## 🛠️ Your Development Environment

### Recommended Setup

```
┌─────────────────────────────────────┐
│  Cursor/VS Code                     │  ← Edit code here
│  (Your comfortable editor)          │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Terminal: make build               │  ← Build from CLI
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Xcode (optional)                   │  ← Debug when needed
│  Press ⌘R to run with debugger      │
└─────────────────────────────────────┘
```

**You don't have to live in Xcode!** Edit in your preferred editor, build from terminal, debug in Xcode only when needed.

---

## 📋 Daily Workflow

### Morning Setup (Once)

```bash
cd /Users/klastochkin/prj/siv

# If first time:
./scripts/install.sh     # Sets everything up
```

### Coding Loop

```bash
# 1. Edit code in Cursor (your current editor)
#    - Files are in SIV/ folder
#    - Main entry: SIV/App/SIVApp.swift
#    - UI: SIV/Views/

# 2. Build
make build

# 3. Run
make run

# 4. See app window open!
#    - Drag an image onto it
#    - Test features

# 5. If something breaks:
make open          # Opens Xcode
# Set breakpoints, press ⌘R, debug
```

---

## 🐛 Debugging for Engineers

### Print Debugging (Familiar)

```swift
// In your Swift code:
print("Debug: value = \(someVariable)")
NSLog("System log: \(message)")

// Output appears in:
// - Xcode debug console (if running from Xcode)
// - Console.app (system logs)
```

### Breakpoint Debugging (Like GDB/Visual Studio)

```bash
# 1. Open in Xcode
make open

# 2. Click line number to set breakpoint (red dot appears)

# 3. Press ⌘R to run with debugger

# 4. When breakpoint hits:
#    - Hover over variables to see values
#    - Use debug console at bottom:

(lldb) po viewModel           # Print object (like p in GDB)
(lldb) p zoomState.scale      # Print value
(lldb) bt                     # Backtrace (call stack)
(lldb) continue               # Resume (like c in GDB)
(lldb) step                   # Step over (like n in GDB)
(lldb) finish                 # Step out
```

### Xcode Shortcuts

| Action | Shortcut | GDB Equivalent |
|--------|----------|----------------|
| Run with debugger | ⌘R | `gdb ./program` |
| Stop | ⌘. | `Ctrl+C` |
| Step Over | F6 | `next` |
| Step Into | F7 | `step` |
| Continue | ⌃⌘Y | `continue` |
| Toggle breakpoint | ⌘\ | `break` |

---

## 📁 Code Tour

**Where to look first:**

```bash
SIV/App/SIVApp.swift          # Entry point (like main())
  ↓
SIV/Views/ImageViewerWindow.swift   # Main window UI
  ↓
SIV/ViewModels/ImageViewModel.swift  # Business logic
  ↓
SIV/Services/                 # Utilities (file I/O, caching)
```

**Reading order for understanding:**
1. `SIV/Models/ImageFile.swift` - Data structures (easy)
2. `SIV/App/SIVApp.swift` - Entry point (30 lines)
3. `SIV/Views/ImageViewerWindow.swift` - UI layout
4. `SIV/ViewModels/ImageViewModel.swift` - Core logic

---

## ❓ FAQ for Your Situation

### Q: Do I need to learn Swift first?

**A:** No! The code is already written. You'll pick up Swift syntax by reading it. It's similar to Kotlin/TypeScript/C#.

### Q: Do I need to learn SwiftUI?

**A:** Not immediately. The UI code is done. You can modify it by pattern matching.

### Q: Can I use my current editor (Cursor)?

**A:** Yes! Edit in Cursor, build with `make build`, run with `make run`. Use Xcode only for debugging.

### Q: What if I break something?

**A:** Swift compiler is strict and helpful. It will tell you exactly what's wrong. Read the error message, it usually tells you the fix.

### Q: How do I add a feature?

**A:** 
1. Read the relevant code (e.g., `ImageViewModel.swift` for business logic)
2. Add your feature (Swift syntax is intuitive)
3. `make build` to see if it compiles
4. `make run` to test

### Q: Where do I see print() output?

**A:** 
- If running from Xcode (⌘R): Debug console at bottom
- If running from terminal (`make run`): Open Console.app (system utility)

### Q: How long until I'm productive?

**A:**
- Day 1: Can build and run ✓
- Day 2: Can modify existing code
- Week 1: Can add new features
- Month 1: Comfortable with Swift/SwiftUI

---

## 🚨 Troubleshooting

### "xcodebuild: command not found"
```bash
xcode-select --install
```

### "Code signing failed"
```bash
# Open Xcode → Preferences → Accounts
# Sign in with Apple ID (free, no developer account needed)
```

### "No such module 'SwiftUI'"
```bash
make clean
make build
```

### App builds but won't run
```bash
# Check if it was built
ls -la build/Debug/SIV.app

# Try opening manually
open build/Debug/SIV.app

# Check Console.app for crash logs
```

### Can't find Xcode after installing
```bash
sudo xcode-select --switch /Applications/Xcode.app
sudo xcodebuild -license accept
```

---

## 🎯 Success Checklist

After setup, verify everything works:

```bash
# ✓ Xcode installed?
xcodebuild -version

# ✓ Project exists?
ls SIV.xcodeproj/project.pbxproj

# ✓ Compiles?
make build

# ✓ Runs?
make run
# Should see window open

# ✓ Works?
# Drag a JPEG onto the window
# Should display the image
# Arrow keys should navigate
# Scroll wheel should zoom
```

**If all ✓ → You're ready to develop!** 🎉

---

## 📚 Learning Resources (Optional)

You don't need these immediately, but for later:

- **Swift Tour**: https://docs.swift.org/swift-book/GuidedTour/GuidedTour.html
- **SwiftUI Tutorials**: https://developer.apple.com/tutorials/swiftui
- **Hacking with Swift**: https://www.hackingwithswift.com/ (best resource)

---

## 🚀 Your Next Step

**Right now, do this:**

```bash
# 1. Install Xcode from App Store (if not installed)
#    https://apps.apple.com/us/app/xcode/id497799835

# 2. Run automated setup
./scripts/install.sh

# 3. Build and run
make run

# 4. See it work!
```

**That's it!** You'll learn the rest by doing.

---

**Questions?** Read:
- `QUICKSTART.md` - Detailed quick start
- `docs/getting-started-cli.md` - CLI workflow guide
- `Makefile` - See all available commands

**You got this! 🚀** The code is already written, you just need to build and run it.

