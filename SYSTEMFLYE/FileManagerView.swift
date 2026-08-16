import SwiftUI

struct FileManagerView: View {
    @StateObject private var viewModel = FileManagerViewModel()
    @State private var showingDeleteConfirmation = false
    @State private var selectedFile: URL?
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tabs
                HStack(spacing: 0) {
                    TabSegment(
                        label: "Sounds",
                        icon: "waveform",
                        isSelected: viewModel.activeTab == 0
                    ) {
                        viewModel.activeTab = 0
                    }
                    
                    TabSegment(
                        label: "Exports",
                        icon: "arrow.up.doc",
                        isSelected: viewModel.activeTab == 1
                    ) {
                        viewModel.activeTab = 1
                    }
                }
                .frame(height: 50)
                .background(Color(red: 0.12, green: 0.12, blue: 0.18))
                
                ScrollView {
                    if (viewModel.activeTab == 0 ? viewModel.sounds : viewModel.exports).isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: viewModel.activeTab == 0 ? "waveform" : "doc.text")
                                .font(.system(size: 48))
                                .foreground(Color.white.opacity(0.3))
                            
                            Text(viewModel.activeTab == 0 ? "No sounds yet" : "No exports yet")
                                .font(.system(size: 16, weight: .semibold))
                                .foreground(.white)
                            
                            Text(viewModel.activeTab == 0 ?
                                 "Save audio from the synthesizer" :
                                 "Export audio to create files")
                                .font(.system(size: 13))
                                .foreground(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.activeTab == 0 ? viewModel.sounds : viewModel.exports, id: \.self) { file in
                                FileCard(
                                    file: file,
                                    viewModel: viewModel,
                                    onDelete: {
                                        selectedFile = file
                                        showingDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadFiles()
        }
        .confirmationDialog(
            "Delete File",
            isPresented: $showingDeleteConfirmation,
            presenting: selectedFile
        ) { file in
            Button("Delete", role: .destructive) {
                viewModel.deleteFile(file)
            }
        } message: { file in
            Text("Are you sure you want to delete \(file.lastPathComponent)?")
        }
    }
}

struct TabSegment: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? Color(red: 0.4, green: 0.8, blue: 1.0) : .white.opacity(0.5))
        }
    }
}

struct FileCard: View {
    let file: URL
    let viewModel: FileManagerViewModel
    let onDelete: () -> Void
    
    @State private var properties: AudioProperties?
    @State private var showingShare = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.lastPathComponent)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let props = properties {
                        HStack(spacing: 12) {
                            Label(
                                String(format: "%.1f MB", props.fileSize),
                                systemImage: "internaldrive"
                            )
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            
                            Label(
                                String(format: "%.1f s", props.duration),
                                systemImage: "clock"
                            )
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { showingShare = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
            )
        }
        .onAppear {
            properties = AudioFileManager.shared.getAudioProperties(from: file)
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(items: [file])
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

class FileManagerViewModel: ObservableObject {
    @Published var sounds: [URL] = []
    @Published var exports: [URL] = []
    @Published var activeTab = 0
    
    func loadFiles() {
        sounds = AudioFileManager.shared.getSavedSounds()
        exports = AudioFileManager.shared.getExportedSounds()
    }
    
    func deleteFile(_ url: URL) {
        try? AudioFileManager.shared.deleteFile(url)
        loadFiles()
    }
}

#Preview {
    FileManagerView()
}
