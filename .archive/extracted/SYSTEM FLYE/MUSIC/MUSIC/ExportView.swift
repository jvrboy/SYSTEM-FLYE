import SwiftUI

struct ExportView: View {
    @StateObject private var viewModel = ExportViewModel()
    @State private var exportFilename = "exported_sound"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Filename Input
                    VStack(spacing: 12) {
                        Text("Filename")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foreground(.white)
                        
                        TextField("Enter filename", text: $exportFilename)
                            .textFieldStyle(.roundedBorder)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                            )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                    )
                    
                    // Audio Format Selection
                    VStack(spacing: 12) {
                        Text("Export Format")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foreground(.white)
                        
                        VStack(spacing: 8) {
                            ForEach(AudioFileManager.AudioFormat.allCases, id: \.self) { format in
                                FormatButton(
                                    format: format,
                                    isSelected: viewModel.selectedFormat == format.rawValue,
                                    action: {
                                        viewModel.selectedFormat = format.rawValue
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                    )
                    
                    // Format Info
                    if let selectedFormat = AudioFileManager.AudioFormat(rawValue: viewModel.selectedFormat) {
                        VStack(spacing: 12) {
                            Text("Format Information")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foreground(.white)
                            
                            FormatInfoCard(
                                title: "File Type",
                                value: selectedFormat.rawValue
                            )
                            
                            FormatInfoCard(
                                title: "Quality",
                                value: getQualityDescription(for: selectedFormat)
                            )
                            
                            FormatInfoCard(
                                title: "Compression",
                                value: getCompressionType(for: selectedFormat)
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                        )
                    }
                    
                    // Advanced Options
                    VStack(spacing: 12) {
                        Text("Advanced Options")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foreground(.white)
                        
                        Toggle("Normalize Audio", isOn: $viewModel.normalizeAudio)
                            .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
                        
                        Toggle("Add Metadata", isOn: $viewModel.addMetadata)
                            .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
                        
                        Toggle("Apply Compression", isOn: $viewModel.applyCompression)
                            .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
                    }
                    .foreground(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                    )
                    
                    // Export Button
                    Button(action: {
                        viewModel.export(filename: exportFilename)
                        showingAlert = true
                        alertMessage = "Audio exported successfully!"
                    }) {
                        if viewModel.isExporting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.black)
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.doc")
                                Text("Export Audio")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.5, green: 0.9, blue: 1.0),
                                        Color(red: 0.3, green: 0.7, blue: 0.9)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .foregroundColor(.black)
                    .disabled(viewModel.isExporting)
                    
                    // Recent Exports
                    if !viewModel.recentExports.isEmpty {
                        VStack(spacing: 12) {
                            Text("Recent Exports")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foreground(.white)
                            
                            VStack(spacing: 8) {
                                ForEach(viewModel.recentExports.prefix(5), id: \.self) { url in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(url.lastPathComponent)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foreground(.white)
                                            
                                            Text(url.pathExtension.uppercased())
                                                .font(.system(size: 12))
                                                .foreground(.white.opacity(0.6))
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { viewModel.shareExport(url) }) {
                                            Image(systemName: "square.and.arrow.up")
                                                .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                                    )
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                        )
                    }
                }
                .padding(16)
            }
        }
        .alert("Export", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func getQualityDescription(for format: AudioFileManager.AudioFormat) -> String {
        switch format {
        case .wav, .aiff: return "24-bit Lossless"
        case .m4a: return "256 kbps"
        case .mp3: return "320 kbps"
        case .flac: return "16-bit Lossless"
        case .alac: return "Lossless"
        }
    }
    
    private func getCompressionType(for format: AudioFileManager.AudioFormat) -> String {
        switch format {
        case .wav, .aiff, .flac, .alac: return "Lossless"
        case .m4a, .mp3: return "Lossy"
        }
    }
}

struct FormatButton: View {
    let format: AudioFileManager.AudioFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(format.fileExtension.uppercased())
                        .font(.system(size: 12))
                        .opacity(0.6)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(red: 0.2, green: 0.4, blue: 0.6) : Color(red: 0.1, green: 0.1, blue: 0.15))
            )
            .foregroundColor(isSelected ? Color(red: 0.4, green: 0.8, blue: 1.0) : .white)
        }
    }
}

struct FormatInfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foreground(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foreground(Color(red: 0.4, green: 0.8, blue: 1.0))
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .cornerRadius(8)
    }
}

class ExportViewModel: ObservableObject {
    @Published var selectedFormat = "WAV (Uncompressed)"
    @Published var normalizeAudio = true
    @Published var addMetadata = true
    @Published var applyCompression = false
    @Published var isExporting = false
    @Published var recentExports: [URL] = []
    
    func export(filename: String) {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Simulate export process
            sleep(1)
            
            DispatchQueue.main.async {
                self.isExporting = false
                self.loadRecentExports()
            }
        }
    }
    
    func shareExport(_ url: URL) {
        // Share functionality
    }
    
    func loadRecentExports() {
        recentExports = AudioFileManager.shared.getExportedSounds()
    }
}

#Preview {
    ExportView()
}
