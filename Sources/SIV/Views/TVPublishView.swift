import SwiftUI

/// Sheet for publishing the album to the TV library folder and running the LAN server.
struct TVPublishView: View {
    @ObservedObject var vm: TVPublishViewModel
    let images: [ImageFile]
    let albumName: String
    @Environment(\.dismiss) private var dismiss

    @State private var portText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "tv")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Publish to TV")
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()

            Form {
                librarySection
                serverSection
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 560, height: 660)
        .onAppear {
            vm.refreshInterfaces()
            portText = String(vm.port)
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        Section("Library") {
            HStack {
                Text(vm.libraryPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.secondary)
                    .help(vm.libraryPath)
                Spacer()
                Button("Choose…") { vm.chooseLibraryFolder() }
                    .disabled(vm.isPublishing)
                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([vm.libraryURL])
                }
            }

            HStack {
                Button(vm.isPublishing ? "Publishing…" : "Publish \(images.count) Photo(s)") {
                    Task { await vm.publish(images: images, albumName: albumName) }
                }
                .disabled(vm.isPublishing || images.isEmpty)
                if vm.isPublishing {
                    ProgressView(value: Double(vm.progressDone), total: Double(max(vm.progressTotal, 1)))
                    Text("\(vm.progressDone)/\(vm.progressTotal)")
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }

            if let report = vm.lastReport, !vm.isPublishing {
                Label(report.summary, systemImage: report.failed.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundColor(report.failed.isEmpty ? .secondary : .orange)
                ForEach(report.failed.prefix(5), id: \.path) { failure in
                    Text("\(URL(fileURLWithPath: failure.path).lastPathComponent): \(failure.reason)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            if let error = vm.errorMessage {
                Label(error, systemImage: "xmark.octagon").foregroundColor(.red)
            }
        }
    }

    // MARK: - Server

    private var serverSection: some View {
        Section("LAN Server") {
            Picker("Listen on", selection: $vm.bindHost) {
                ForEach(vm.interfaces, id: \.self) { iface in
                    Text("\(iface.address) (\(iface.name))").tag(iface.address)
                }
                Text("All interfaces").tag("")
                if !vm.bindHost.isEmpty, !vm.interfaces.contains(where: { $0.address == vm.bindHost }) {
                    Text("\(vm.bindHost) (unavailable)").tag(vm.bindHost)
                }
            }
            .disabled(vm.isServerRunning)

            TextField("Port", text: $portText)
                .disabled(vm.isServerRunning)
                .onChange(of: portText) { newValue in
                    if let value = UInt16(newValue), value > 0 { vm.port = value }
                }

            HStack {
                TextField("Access token (optional)", text: $vm.token)
                    .disabled(vm.isServerRunning)
                Button("Generate") { vm.generateToken() }
                    .disabled(vm.isServerRunning)
            }

            if let warning = vm.exposureWarning {
                Label(warning, systemImage: "exclamationmark.shield")
                    .foregroundColor(.orange)
            }

            HStack {
                switch vm.serverState {
                case .running:
                    Button("Stop Server") { vm.stopServer() }
                case .starting:
                    ProgressView().controlSize(.small)
                    Text("Starting…").foregroundColor(.secondary)
                default:
                    Button("Start Server") { Task { await vm.startServer() } }
                }
                Spacer()
            }

            if case .failed(let reason) = vm.serverState {
                Label(reason, systemImage: "xmark.octagon").foregroundColor(.red)
            }

            if let url = vm.serverURL {
                VStack(alignment: .leading, spacing: 6) {
                    Text("On the TV, open SIV TV → Settings and enter:")
                        .foregroundColor(.secondary)
                    HStack {
                        Text(url).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url, forType: .string)
                        } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless)
                        .help("Copy URL")
                    }
                    if !vm.token.isEmpty {
                        Text("Token: \(vm.token)")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    Text("Do not port-forward this port on your router.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
