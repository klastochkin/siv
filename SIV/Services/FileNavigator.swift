import Foundation

/// Service responsible for navigating through image files in a folder
class FileNavigator {
    
    /// Errors that can occur during file navigation
    enum NavigationError: Error {
        case folderNotAccessible
        case noImagesFound
    }
    
    /// Gets all supported image files in the same folder as the given file
    func getImagesInFolder(of fileURL: URL) throws -> [ImageFile] {
        let folderURL = fileURL.deletingLastPathComponent()
        
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            throw NavigationError.folderNotAccessible
        }
        
        var imageFiles: [ImageFile] = []
        
        for case let fileURL as URL in enumerator {
            // Check if it's a regular file
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else {
                continue
            }
            
            // Check if it's a supported image format
            let ext = fileURL.pathExtension.lowercased()
            guard ImageFormat.supportedExtensions.contains(ext) else {
                continue
            }
            
            // Create ImageFile
            if let imageFile = try? ImageFile(url: fileURL) {
                imageFiles.append(imageFile)
            }
        }
        
        guard !imageFiles.isEmpty else {
            throw NavigationError.noImagesFound
        }
        
        // Sort alphabetically by filename
        imageFiles.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        
        return imageFiles
    }
    
    /// Gets the next image after the current one (wraps around)
    func nextImage(after current: ImageFile, in images: [ImageFile]) -> ImageFile? {
        guard let currentIndex = images.firstIndex(of: current) else {
            return nil
        }
        
        let nextIndex = (currentIndex + 1) % images.count
        return images[nextIndex]
    }
    
    /// Gets the previous image before the current one (wraps around)
    func previousImage(before current: ImageFile, in images: [ImageFile]) -> ImageFile? {
        guard let currentIndex = images.firstIndex(of: current) else {
            return nil
        }
        
        let previousIndex = (currentIndex - 1 + images.count) % images.count
        return images[previousIndex]
    }
    
    /// Gets the index of an image in the list
    func indexOf(_ image: ImageFile, in images: [ImageFile]) -> Int? {
        return images.firstIndex(of: image)
    }
}

