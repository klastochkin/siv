# Project Setup Guide

## Creating the Xcode Project

Since this is a Swift/SwiftUI project, you'll need to create an Xcode project to build and run the app.

### Steps

1. **Open Xcode** and select "Create a new Xcode project"

2. **Choose macOS → App template**

3. **Configure the project:**
   - Product Name: `SIV`
   - Team: (Your development team)
   - Organization Identifier: `com.yourname.siv`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Storage: `None`
   - Include Tests: ✅ (checked)

4. **Save to the project directory** (select the `/Users/klastochkin/prj/siv` folder)

5. **Add existing source files:**
   - Delete the default `SIVApp.swift` and `ContentView.swift` created by Xcode
   - Add the `SIV/` folder to the project (drag into Xcode)
   - Add the `SIVTests/` folder to the test target

6. **Configure Info.plist:**
   - Add document types for supported image formats
   - Configure file associations

7. **Configure minimum deployment target:**
   - Project Settings → Deployment Info → macOS Deployment Target: `13.0`

### Info.plist Configuration

Add these document types to support opening image files:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Image</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.jpeg</string>
            <string>public.png</string>
            <string>public.heif</string>
            <string>public.heic</string>
        </array>
    </dict>
</array>
```

### App Icon

1. Create app icon using `Assets.xcassets`
2. Recommended size: 1024x1024 px
3. Simple design: Photo frame, aperture, or mountain silhouette

### Build Configuration

**Debug:**
- Enable all warnings
- Treat warnings as errors
- Enable Address Sanitizer (for memory debugging)

**Release:**
- Optimization: `-O` (Speed)
- Strip debug symbols
- Enable bitcode (if applicable)

## Running the Project

1. Select the `SIV` scheme in Xcode
2. Press `⌘R` to build and run
3. The app should launch with an empty window
4. Test by dragging an image onto the window or using `⌘O`

## Development Workflow

1. Make changes in your preferred editor (Cursor, VS Code, etc.)
2. Switch to Xcode
3. Xcode will detect file changes automatically
4. Build and run to test

## Common Issues

### "Module not found" errors
- Solution: Clean build folder (`⌘⇧K`) and rebuild

### SwiftUI preview not working
- Solution: Ensure all preview files have `#Preview` macros
- Try cleaning and rebuilding

### File changes not detected
- Solution: Restart Xcode or clean build folder

## Next Steps

After setup:
1. ✅ Verify project builds successfully
2. ✅ Run on macOS 13+ device
3. ✅ Test basic functionality (empty state shows)
4. ✅ Configure code signing
5. ✅ Add app icon
6. ✅ Test with sample images

