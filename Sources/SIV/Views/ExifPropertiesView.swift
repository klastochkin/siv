import SwiftUI
import MapKit

private struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct ExifPropertiesView: View {
    let imageFile: ImageFile
    @Environment(\.dismiss) var dismiss
    
    @State private var exifData: ExifData?
    @State private var selectedTab = 0
    
    // Editable fields
    @State private var editedDate: Date = Date()
    @State private var hasDate = false
    @State private var editedLatitude = ""
    @State private var editedLongitude = ""
    @State private var editedAltitude = ""
    @State private var hasLocation = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            TabView(selection: $selectedTab) {
                generalTab.tag(0)
                    .tabItem { Label("General", systemImage: "doc.text") }
                cameraTab.tag(1)
                    .tabItem { Label("Camera", systemImage: "camera") }
                locationTab.tag(2)
                    .tabItem { Label("Location", systemImage: "map") }
            }
            .padding(.top, 4)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            Divider()
            footer
        }
        .frame(minWidth: 480, minHeight: 500)
        .onAppear { loadExifData() }
    }
    
    // MARK: - Header / Footer
    
    private var header: some View {
        HStack {
            Image(systemName: "info.circle")
            Text(imageFile.fileName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding()
    }
    
    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving)
        }
        .padding()
    }
    
    // MARK: - Tab 1: General
    
    private var generalTab: some View {
        Form {
            Section("File") {
                LabeledContent("Name", value: imageFile.fileName)
                LabeledContent("Path") {
                    Text(imageFile.path)
                        .textSelection(.enabled)
                        .foregroundColor(.secondary)
                }
                if let size = imageFile.fileSize {
                    LabeledContent("Size", value: formatFileSize(size))
                }
            }
            
            if let exif = exifData {
                if exif.pixelWidth != nil || exif.pixelHeight != nil {
                    Section("Image") {
                        if let w = exif.pixelWidth, let h = exif.pixelHeight {
                            LabeledContent("Dimensions", value: "\(w) × \(h) px")
                        }
                        if let cs = exif.colorSpace {
                            LabeledContent("Color Space", value: cs)
                        }
                        if let o = exif.orientation {
                            LabeledContent("Orientation", value: orientationLabel(o))
                        }
                    }
                }
                
                Section("Date / Time") {
                    Toggle("Has date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Original", selection: $editedDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    if let digitized = exif.dateTimeDigitized, digitized != exif.dateTimeOriginal {
                        LabeledContent("Digitized", value: digitized.formatted(date: .abbreviated, time: .standard))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Tab 2: Camera & Exposure
    
    private var cameraTab: some View {
        Form {
            if let exif = exifData {
                Section("Camera") {
                    if let make = exif.cameraMake {
                        LabeledContent("Make", value: make.trimmingCharacters(in: .whitespaces))
                    }
                    if let model = exif.cameraModel {
                        LabeledContent("Model", value: model.trimmingCharacters(in: .whitespaces))
                    }
                    if let lens = exif.lensModel {
                        LabeledContent("Lens", value: lens.trimmingCharacters(in: .whitespaces))
                    }
                    if exif.cameraMake == nil && exif.cameraModel == nil && exif.lensModel == nil {
                        Text("No camera information available")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Exposure") {
                    if let iso = exif.isoSpeed {
                        LabeledContent("ISO", value: "\(iso)")
                    }
                    if let ap = exif.apertureFormatted {
                        LabeledContent("Aperture", value: ap)
                    }
                    if let ss = exif.shutterSpeedFormatted {
                        LabeledContent("Shutter Speed", value: ss)
                    }
                    if let fl = exif.focalLength {
                        LabeledContent("Focal Length", value: String(format: "%.0f mm", fl))
                    }
                    if exif.isoSpeed == nil && exif.aperture == nil && exif.shutterSpeed == nil && exif.focalLength == nil {
                        Text("No exposure information available")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Section {
                    Text("No EXIF data available")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Tab 3: Location
    
    private var locationTab: some View {
        VStack(spacing: 0) {
            Form {
                Section("GPS Coordinates") {
                    Toggle("Has location", isOn: $hasLocation)
                    if hasLocation {
                        HStack {
                            Text("Lat")
                                .frame(width: 30, alignment: .trailing)
                                .foregroundColor(.secondary)
                            TextField("Latitude", text: $editedLatitude)
                                .onChange(of: editedLatitude) { _ in updateMapRegion() }
                        }
                        HStack {
                            Text("Lon")
                                .frame(width: 30, alignment: .trailing)
                                .foregroundColor(.secondary)
                            TextField("Longitude", text: $editedLongitude)
                                .onChange(of: editedLongitude) { _ in updateMapRegion() }
                        }
                        HStack {
                            Text("Alt")
                                .frame(width: 30, alignment: .trailing)
                                .foregroundColor(.secondary)
                            TextField("Altitude (optional)", text: $editedAltitude)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: 180)
            
            if hasLocation, let lat = Double(editedLatitude), let lon = Double(editedLongitude) {
                let pins = [MapPin(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))]
                Map(coordinateRegion: $mapRegion, annotationItems: pins) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: .red)
                }
                .cornerRadius(8)
                .padding([.horizontal, .bottom], 12)
                .onTapGesture {
                    let urlString = "maps://?ll=\(lat),\(lon)&q=\(lat),\(lon)"
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .help("Click to open in Maps")
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "map")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No location data")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            }
        }
    }
    
    // MARK: - Logic
    
    private func loadExifData() {
        exifData = ExifService.readExifData(from: imageFile.path)
        guard let exif = exifData else { return }
        
        if let date = exif.dateTimeOriginal {
            editedDate = date
            hasDate = true
        }
        if let lat = exif.latitude, let lon = exif.longitude {
            editedLatitude = String(format: "%.6f", lat)
            editedLongitude = String(format: "%.6f", lon)
            hasLocation = true
            if let alt = exif.altitude {
                editedAltitude = String(format: "%.1f", alt)
            }
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
    }
    
    private func updateMapRegion() {
        guard let lat = Double(editedLatitude), let lon = Double(editedLongitude) else { return }
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: mapRegion.span
        )
    }
    
    private func save() {
        isSaving = true
        errorMessage = nil
        
        do {
            if hasDate {
                try ExifService.writeDate(editedDate, to: imageFile.path)
            }
            
            if hasLocation,
               let lat = Double(editedLatitude),
               let lon = Double(editedLongitude) {
                let alt = Double(editedAltitude)
                try ExifService.writeLocation(latitude: lat, longitude: lon, altitude: alt, to: imageFile.path)
            } else if !hasLocation && exifData?.latitude != nil {
                try ExifService.removeLocation(from: imageFile.path)
            }
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
    
    private func orientationLabel(_ value: Int) -> String {
        switch value {
        case 1: return "Normal"
        case 2: return "Mirrored"
        case 3: return "Rotated 180°"
        case 4: return "Mirrored + 180°"
        case 5: return "Mirrored + 90° CW"
        case 6: return "Rotated 90° CW"
        case 7: return "Mirrored + 90° CCW"
        case 8: return "Rotated 90° CCW"
        default: return "\(value)"
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
