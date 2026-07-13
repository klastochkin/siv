import SwiftUI

/// Multi-step sheet for importing new photos from a connected memory card.
struct MemCardImportView: View {
    @ObservedObject var vm: MemCardImportViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            Divider()
            footer
        }
        .frame(width: 520, height: 460)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sdcard")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("Upload from Memory Card")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .detecting:
            centered {
                ProgressView()
                Text("Looking for a memory card…").foregroundColor(.secondary)
            }
        case .noCard:
            noCardView
        case .selectCard:
            selectCardView
        case .scanning:
            centered {
                ProgressView()
                Text("Scanning \(vm.selectedCard?.name ?? "card")…").foregroundColor(.secondary)
            }
        case .review:
            reviewView
        case .copying:
            copyingView
        case .finished:
            finishedView
        case .error:
            centered {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle).foregroundColor(.orange)
                Text(vm.errorMessage ?? "Something went wrong.")
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var noCardView: some View {
        centered {
            Image(systemName: "sdcard")
                .font(.system(size: 48)).foregroundColor(.gray)
            Text("No memory card detected")
                .font(.title3)
            Text("Connect a memory card or card reader, then rescan.")
                .font(.callout).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var selectCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(vm.cards.count == 1 ? "Found a memory card:" : "Select a memory card:")
                .font(.subheadline)

            ForEach(vm.cards) { card in
                Button {
                    vm.selectedCard = card
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: card.hasDCIM ? "camera.fill" : "externaldrive.fill")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.name).font(.body)
                            Text(card.hasDCIM ? "Camera card (DCIM)" : card.url.path)
                                .font(.caption).foregroundColor(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        if vm.selectedCard == card {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(vm.selectedCard == card ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reviewView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                statsBox
                if vm.newFileCount > 0 {
                    Button {
                        showDetails.toggle()
                    } label: {
                        Label("Details", systemImage: showDetails ? "chevron.up" : "list.bullet")
                    }
                    .controlSize(.small)
                }
            }

            if showDetails && vm.newFileCount > 0 {
                fileDetailsList
            } else if vm.newFileCount > 0 {
                Text("Copy to which folder?")
                    .font(.subheadline)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(vm.folderOptions) { folder in
                            folderRow(folder)
                        }
                    }
                }

                Button {
                    vm.chooseCustomFolder()
                } label: {
                    Label("Choose Another Folder…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.link)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileDetailsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Files to copy (click to preview)")
                .font(.caption).foregroundColor(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(vm.newFiles, id: \.self) { url in
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "photo").foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(url.lastPathComponent).font(.callout)
                                    Text(url.deletingLastPathComponent().path)
                                        .font(.caption2).foregroundColor(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 3).padding(.horizontal, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
        }
    }

    private var statsBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "photo.stack")
                Text("\(vm.totalOnCard) images on \(vm.selectedCard?.name ?? "card")")
            }
            .font(.callout)

            if let synced = vm.latestSyncedName {
                Text("Last synced file: \(synced)")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                Text("No previously synced files found — treating all as new.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Text("\(vm.newFileCount) new file\(vm.newFileCount == 1 ? "" : "s") to import")
                .font(.headline)
                .foregroundColor(vm.newFileCount > 0 ? .accentColor : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
    }

    private func folderRow(_ folder: MemCardImportViewModel.FolderOption) -> some View {
        Button {
            vm.selectedFolder = folder
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill").foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name).font(.body)
                    Text(folder.path)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if folder.count > 0 {
                    Text("\(folder.count)")
                        .font(.caption).foregroundColor(.secondary)
                }
                if vm.selectedFolder == folder {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(vm.selectedFolder == folder ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private var copyingView: some View {
        centered {
            ProgressView(value: Double(vm.copiedCount), total: Double(max(vm.newFileCount, 1)))
                .frame(width: 260)
            Text("Copying \(vm.copiedCount) of \(vm.newFileCount)…")
                .foregroundColor(.secondary)
        }
    }

    private var finishedView: some View {
        centered {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48)).foregroundColor(.green)
            Text("Imported \(vm.copiedCount) file\(vm.copiedCount == 1 ? "" : "s")")
                .font(.title3)
            if let folder = vm.selectedFolder {
                Text("into \(folder.name)")
                    .font(.callout).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            switch vm.phase {
            case .noCard, .error:
                Button("Rescan") { vm.rescan() }
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            case .selectCard:
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Continue") { vm.confirmCard() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(vm.selectedCard == nil)
            case .review:
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import \(vm.newFileCount) File\(vm.newFileCount == 1 ? "" : "s")") { vm.startCopy() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(vm.newFileCount == 0 || vm.selectedFolder == nil)
            case .finished:
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            case .copying:
                Text("\(vm.progressPercent)%").foregroundColor(.secondary)
                Spacer()
                Button("Run in Background") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            case .detecting, .scanning:
                Spacer()
                Button("Cancel") { dismiss() }
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 12) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
