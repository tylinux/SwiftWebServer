import SwiftUI

struct UploadedFilesView: View {
    let uploadRoot: URL
    @State private var files: [URL] = []

    var body: some View {
        NavigationStack {
            List(files, id: \.self) { file in
                NavigationLink(value: file) {
                    HStack {
                        Image(systemName: "doc")
                        VStack(alignment: .leading) {
                            Text(file.lastPathComponent)
                            Text(formatSize(of: file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Uploaded Files")
            .navigationDestination(for: URL.self) { file in
                FileDetailView(file: file)
            }
            .overlay {
                if files.isEmpty {
                    ContentUnavailableView("No uploaded files", systemImage: "folder")
                }
            }
            .task { loadFiles() }
            .refreshable { loadFiles() }
        }
    }

    private func loadFiles() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: uploadRoot,
                includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            )
            files = urls.filter { !$0.hasDirectoryPath }
        } catch {
            files = []
        }
    }
}

struct FileDetailView: View {
    let file: URL
    @State private var content: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(file.lastPathComponent)
                .font(.headline)
            Text("Size: \(formatSize(of: file))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()

            if let content {
                ScrollView {
                    Text(content)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Spacer()
                ContentUnavailableView("Preview not available", systemImage: "doc.text")
                Spacer()
            }
        }
        .padding()
        .navigationTitle("File Detail")
        .task { loadContent() }
    }

    private func loadContent() {
        content = try? String(contentsOf: file, encoding: .utf8)
    }
}

private func formatSize(of url: URL) -> String {
    guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
          let size = values.fileSize else {
        return "Unknown size"
    }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(size))
}
