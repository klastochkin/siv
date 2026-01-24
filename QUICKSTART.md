# Quick Start Guide

## Installation

1. **Clone and Build**
   ```bash
   cd /path/to/siv
   make build
   ```

2. **Run the Application**
   ```bash
   swift run
   ```

## First Use

### Opening Images

1. **Via Menu**: File → Open Image... (or Cmd+O)
2. **Drag & Drop**: Drag an image file into the Image View

### Working with Albums

1. **Add Images to Album**: 
   - File → Add to Album... (or Cmd+A while viewing an image)
   - Or drag images into the Album View

2. **Navigate Images**:
   - Click an image in the Album View to display it
   - Use arrow keys to move between images
   - Press Space to go to next image

3. **View Modes**:
   - Toggle between List and Thumbnails using the segmented control in the Album View

### Zoom and Pan

**Zoom In/Out**:
- Scroll wheel: Natural scrolling with fine control
- Trackpad pinch: Two-finger pinch gesture
- Keyboard: Cmd++ / Cmd+-

**Reset Zoom**:
- Cmd+0: Fit to window
- Cmd+1: Actual size (100%)

**Pan Around**:
- Arrow keys: Move in 50px increments
- Trackpad: Two-finger drag

### View Management

- **Tab Key**: Switch focus between Album and Image views
- **Menu → View → Toggle Album/Image View**: Show/hide Album panel

## Common Workflows

### Quick Image Review
1. Open SIV
2. File → Add to Album... (select multiple images)
3. Use arrow keys to navigate through images
4. Use zoom controls to inspect details

### Single Image Inspection
1. Cmd+O to open an image
2. Cmd+1 for actual size
3. Use arrow keys to pan around
4. Cmd+A to add to album if needed

## Tips

- The default album is automatically created at: `~/Library/Application Support/SIV/default.sivalb`
- Missing files are marked with a red X - use the dialog to remove them
- Album View and Image View respond differently to arrow keys based on focus
- All album changes are saved automatically

## Troubleshooting

**App won't build?**
```bash
make clean
make build
```

**Images not loading?**
- Check that the image format is supported (JPEG, PNG, HEIF)
- Verify file permissions

**Missing files in album?**
- Click "Remove All Missing Files" when prompted
- Or manually select and remove them

## Development

**Run Tests**:
```bash
make test
```

**Generate Xcode Project**:
```bash
make xcode
```

**Clean Build**:
```bash
make clean
```
