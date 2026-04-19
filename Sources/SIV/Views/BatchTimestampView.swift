import SwiftUI

struct BatchTimestampView: View {
    let imageFiles: [ImageFile]
    @Environment(\.dismiss) var dismiss
    
    @State private var baseDate: Date = Date()
    @State private var deltaSeconds: Double = 1.0
    @State private var isApplying = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            Form {
                Section("Settings") {
                    DatePicker("Base date/time", selection: $baseDate, displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text("Delta between files")
                        Spacer()
                        TextField("", value: $deltaSeconds, format: .number)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        Text("sec")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Preview (\(imageFiles.count) files)") {
                    ForEach(Array(imageFiles.prefix(20).enumerated()), id: \.element.id) { index, file in
                        HStack {
                            Text(file.fileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(previewDate(for: index))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if imageFiles.count > 20 {
                        Text("… and \(imageFiles.count - 20) more")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 400)
        .onAppear { loadBaseDateFromFirstFile() }
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.2.circlepath")
            Text("Batch Set Timestamps")
                .font(.headline)
            Spacer()
        }
        .padding()
    }
    
    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Apply to \(imageFiles.count) files") { apply() }
                .keyboardShortcut(.defaultAction)
                .disabled(isApplying)
        }
        .padding()
    }
    
    private func previewDate(for index: Int) -> String {
        let date = baseDate.addingTimeInterval(Double(index) * deltaSeconds)
        return date.formatted(date: .abbreviated, time: .standard)
    }
    
    private func loadBaseDateFromFirstFile() {
        guard let first = imageFiles.first,
              let exif = ExifService.readExifData(from: first.path),
              let date = exif.dateTimeOriginal else { return }
        baseDate = date
    }
    
    private func apply() {
        isApplying = true
        errorMessage = nil
        
        let paths = imageFiles.map { $0.path }
        do {
            try ExifService.applyTimestampDelta(to: paths, baseDate: baseDate, deltaSeconds: deltaSeconds)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isApplying = false
    }
}
