# Product Manager Checklist - Phase 1

## Pre-Development ✅

- [x] Define project goals
- [x] Document requirements
- [x] Review and expand requirements
- [x] Design UI/UX layout
- [x] Define technical architecture
- [x] Create project structure
- [x] Document all specifications
- [x] Write all source code
- [x] Create test framework

## Development Setup 🔄

- [ ] Create Xcode project
- [ ] Configure project settings
- [ ] Add source files to Xcode
- [ ] Configure Info.plist
- [ ] Add file type associations
- [ ] Set minimum macOS version (13.0)
- [ ] Configure code signing
- [ ] Create app icon
- [ ] Add to Assets.xcassets

## Build & Compilation ⏳

- [ ] Initial build succeeds
- [ ] Zero compiler errors
- [ ] Zero compiler warnings
- [ ] All targets build successfully
- [ ] Test target builds
- [ ] SwiftUI previews work

## Feature Testing ⏳

### Core Functionality
- [ ] App launches successfully
- [ ] Window opens with correct size
- [ ] Empty state displays correctly
- [ ] Can open image via ⌘O
- [ ] Can open image via drag & drop
- [ ] Image displays centered
- [ ] Image scales to fit window
- [ ] Aspect ratio preserved

### File Format Support
- [ ] JPEG files open correctly
- [ ] PNG files open correctly
- [ ] HEIF/HEIC files open correctly
- [ ] Unsupported formats show error
- [ ] Corrupted files show error
- [ ] Missing files show error

### Navigation
- [ ] Right arrow navigates to next image
- [ ] Left arrow navigates to previous image
- [ ] Space bar navigates to next image
- [ ] Navigation wraps around (last → first)
- [ ] Only image files in folder are included
- [ ] Files sorted alphabetically
- [ ] Navigation is fast (<100ms)

### Zoom & Pan
- [ ] Scroll wheel zooms in/out
- [ ] Trackpad pinch zooms in/out
- [ ] Zoom centers on cursor position
- [ ] ⌘+ zooms in
- [ ] ⌘- zooms out
- [ ] ⌘0 fits to window
- [ ] ⌘1 shows actual size (100%)
- [ ] Zoom range respected (10%-1600%)
- [ ] Can pan when zoomed in (drag)
- [ ] Cannot pan when fit to window
- [ ] Zoom is smooth and responsive

### Information Display
- [ ] Info bar displays by default
- [ ] Filename shown correctly
- [ ] Image dimensions shown correctly
- [ ] File size formatted correctly
- [ ] Zoom percentage shown correctly
- [ ] Info updates when navigating
- [ ] 'I' key toggles info bar
- [ ] Info bar persists across images

### Window Management
- [ ] Window is resizable
- [ ] Minimum size enforced (400×300)
- [ ] Image rescales when window resizes
- [ ] Multiple windows work independently
- [ ] ⌘W closes window
- [ ] Closing last window quits app
- [ ] Window position remembered (if implemented)

### Menu Bar
- [ ] File → Open works (⌘O)
- [ ] File → Close Window works (⌘W)
- [ ] File → Quit works (⌘Q)
- [ ] View → Zoom In works (⌘=)
- [ ] View → Zoom Out works (⌘-)
- [ ] View → Actual Size works (⌘1)
- [ ] View → Fit to Window works (⌘0)
- [ ] View → Toggle Info Bar works (I)
- [ ] View → Next Image works (→)
- [ ] View → Previous Image works (←)
- [ ] All keyboard shortcuts work

### Visual Design
- [ ] Light mode looks correct
- [ ] Dark mode looks correct
- [ ] Automatic mode switching works
- [ ] Colors match system
- [ ] Typography is readable
- [ ] Info bar is semi-transparent
- [ ] Separator line visible
- [ ] Empty state looks professional
- [ ] Error state looks professional
- [ ] Loading state shows properly

## Performance Testing ⏳

- [ ] Cold start < 1 second
- [ ] Image load (5MB) < 200ms
- [ ] Navigation < 100ms response
- [ ] Zoom feels instant (<16ms)
- [ ] No lag when panning
- [ ] Window resize is smooth
- [ ] Memory usage reasonable
- [ ] No memory leaks (Instruments check)
- [ ] CPU usage low when idle
- [ ] Large images (50MB+) load efficiently

## Error Handling ⏳

- [ ] File not found shows alert
- [ ] Unsupported format shows alert
- [ ] Corrupted file shows alert
- [ ] Permission denied shows alert
- [ ] All error messages user-friendly
- [ ] App doesn't crash on any error
- [ ] Can recover from errors

## Edge Cases ⏳

- [ ] Single image in folder (no navigation)
- [ ] Empty folder (no images)
- [ ] Very small image (< 100px)
- [ ] Very large image (> 100MB)
- [ ] Very wide aspect ratio (21:9)
- [ ] Very tall aspect ratio (9:21)
- [ ] Image with spaces in filename
- [ ] Image with special characters in name
- [ ] Image on external drive
- [ ] Image on network drive
- [ ] Folder with 1000+ images
- [ ] Opening same image in multiple windows

## Code Quality ⏳

- [ ] All unit tests pass
- [ ] Test coverage > 70%
- [ ] No force unwraps (!)
- [ ] Proper error handling throughout
- [ ] Code follows Swift style guide
- [ ] No commented-out code
- [ ] No TODO/FIXME remaining
- [ ] All files have proper headers
- [ ] Documentation comments complete

## Documentation ⏳

- [ ] README.md complete
- [ ] Installation instructions clear
- [ ] Usage guide accurate
- [ ] Keyboard shortcuts documented
- [ ] Architecture documented
- [ ] All design docs complete
- [ ] Code comments sufficient
- [ ] API documentation (if applicable)

## Polish ⏳

- [ ] App icon looks professional
- [ ] App name correct in menu bar
- [ ] About dialog (if implemented)
- [ ] Help menu items work
- [ ] App version number set
- [ ] Copyright info correct
- [ ] No placeholder text
- [ ] No debug logging in release

## User Acceptance Testing ⏳

- [ ] Can use without reading docs
- [ ] Keyboard shortcuts feel natural
- [ ] Gestures feel responsive
- [ ] UI is intuitive
- [ ] Performance feels fast
- [ ] No confusing behaviors
- [ ] Matches expectations of macOS app
- [ ] Would use instead of Preview.app

## Release Preparation ⏳

- [ ] Version number set (1.0.0)
- [ ] Release notes written
- [ ] Known issues documented
- [ ] Future features listed
- [ ] License file included
- [ ] Distribution method decided
- [ ] Code signing configured
- [ ] Notarization (if distributing)

## Phase 1 Acceptance Criteria ⏳

### Must Have ✅ (All coded, need testing)
- [ ] Open JPEG, PNG, HEIF images
- [ ] Display image centered, scaled to fit
- [ ] Navigate between images with keyboard
- [ ] Zoom with scroll/pinch
- [ ] Pan when zoomed in
- [ ] Display filename, dimensions, file size
- [ ] Toggle info bar
- [ ] All keyboard shortcuts work
- [ ] Drag & drop support
- [ ] Multiple windows
- [ ] Light/dark mode
- [ ] Error handling

### Nice to Have (Phase 2)
- [ ] Thumbnail grid view
- [ ] Basic editing (rotate, crop)
- [ ] EXIF data viewing
- [ ] Folder watching
- [ ] Slideshow mode

## Sign-Off ⏳

### Developer Sign-Off
- [ ] All code complete
- [ ] All tests passing
- [ ] No known critical bugs
- [ ] Ready for PM review

### PM Sign-Off (You)
- [ ] All requirements met
- [ ] Quality acceptable
- [ ] Performance acceptable
- [ ] User experience acceptable
- [ ] Ready for Phase 2 planning

### Stakeholder Sign-Off
- [ ] Demo completed
- [ ] Feedback incorporated
- [ ] Approved for use

## Metrics to Track

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Cold Start Time | <1s | ___ | ⏳ |
| Image Load (5MB) | <200ms | ___ | ⏳ |
| Navigation Speed | <100ms | ___ | ⏳ |
| Memory Usage | <500MB | ___ | ⏳ |
| Test Coverage | >70% | ___ | ⏳ |
| Bug Count | 0 critical | ___ | ⏳ |
| User Satisfaction | "Would use" | ___ | ⏳ |

## Issues Log

| ID | Issue | Severity | Status | Resolution |
|----|-------|----------|--------|------------|
| - | (Track issues here) | - | - | - |

## Timeline

| Phase | Estimated | Actual | Status |
|-------|-----------|--------|--------|
| Planning | 2h | 2h | ✅ |
| Design | 3h | 3h | ✅ |
| Coding | 10h | 10h | ✅ |
| Xcode Setup | 1h | ___ | ⏳ |
| Testing | 4h | ___ | ⏳ |
| Bug Fixes | 2h | ___ | ⏳ |
| Polish | 2h | ___ | ⏳ |
| **Total** | **24h** | **15h** | **62%** |

## Next Steps

1. **Immediate (Today):**
   - [ ] Create Xcode project
   - [ ] Import source files
   - [ ] Fix any build errors
   - [ ] Run first build

2. **Short Term (This Week):**
   - [ ] Complete all feature testing
   - [ ] Fix critical bugs
   - [ ] Performance testing
   - [ ] Polish UI

3. **Medium Term (Next Week):**
   - [ ] User acceptance testing
   - [ ] Documentation review
   - [ ] Release preparation
   - [ ] Phase 2 planning

## Notes

_(Use this space for additional notes, observations, or decisions made during development)_

---

**Last Updated:** January 2, 2026  
**Phase:** 1 - Core Viewing  
**Status:** 🏗️ Development Ready (awaiting Xcode setup)

