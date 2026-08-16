import SwiftUI
import PhotosUI

struct ImageToAudioView: View {
    @StateObject private var viewModel = ImageToAudioViewModel()
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Image Preview
                    if let image = viewModel.selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .cornerRadius(16)
                            .clipped()
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.3, green: 0.5, blue: 0.8),
                                                Color(red: 0.2, green: 0.4, blue: 0.6)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foreground(Color(red: 0.4, green: 0.8, blue: 1.0))
                            
                            Text("Select or capture an image")
                                .font(.system(size: 16, weight: .semibold))
                                .foreground(.white)
                            
                            Text("Your image will be analyzed and converted to audio")
                                .font(.system(size: 13))
                                .foreground(.white.opacity(0.6))
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.3, green: 0.5, blue: 0.8),
                                                    Color(red: 0.2, green: 0.4, blue: 0.6)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        )
                    }
                    
                    // Image Selection Buttons
                    HStack(spacing: 12) {
                        PhotosPicker(
                            selection: $photosPickerItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label("Browse", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.2, green: 0.4, blue: 0.6))
                                )
                                .foregroundColor(.white)
                        }
                        .onChange(of: photosPickerItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    if let image = UIImage(data: data) {
                                        viewModel.selectedImage = image
                                    }
                                }
                            }
                        }
                        
                        Button(action: { showingCamera = true }) {
                            Label("Camera", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.4, green: 0.8, blue: 1.0))
                                )
                                .foregroundColor(.black)
                        }
                    }
                    
                    // Mapping Settings
                    VStack(spacing: 12) {
                        Text("Sound Mapping")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foreground(.white)
                        
                        Toggle("Brightness → Amplitude", isOn: $viewModel.brightnessToAmplitude)
                            .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
                        
                        Toggle("Color → Frequency", isOn: $viewModel.colorToFrequency)
                            .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
                        
                        Toggle("Spatial Distribution", isOn: $viewModel.spatialDistribution)
                            .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
                        
                        Toggle("Texture → Grain", isOn: $viewModel.textureGraininess)
                            .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
                    }
                    .foreground(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                    )
                    
                    // Audio Parameters
                    VStack(spacing: 12) {
                        Text("Audio Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foreground(.white)
                        
                        ParameterSlider(
                            label: "Base Frequency",
                            value: $viewModel.baseFrequency,
                            range: 20...2000,
                            unit: "Hz"
                        )
                        
                        ParameterSlider(
                            label: "Frequency Range",
                            value: $viewModel.frequencyRange,
                            range: 100...8000,
                            unit: "Hz"
                        )
                        
                        ParameterSlider(
                            label: "Duration",
                            value: $viewModel.duration,
                            range: 1...30,
                            unit: "s"
                        )
                        
                        Stepper(
                            "Harmonics: \(viewModel.harmonics)",
                            value: $viewModel.harmonics,
                            in: 1...16
                        )
                        .foreground(.white)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                    )
                    
                    // Convert Button
                    if viewModel.selectedImage != nil {
                        Button(action: viewModel.convertToAudio) {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.black)
                            } else {
                                Text("Convert to Audio")
                                    .font(.system(size: 16, weight: .semibold))
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
                        .disabled(viewModel.isProcessing)
                    }
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePickerCamera(image: $viewModel.selectedImage)
        }
    }
}

class ImageToAudioViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var brightnessToAmplitude = true
    @Published var colorToFrequency = true
    @Published var spatialDistribution = true
    @Published var textureGraininess = true
    @Published var baseFrequency: Float = 440
    @Published var frequencyRange: Float = 2000
    @Published var duration: Float = 5.0
    @Published var harmonics = 8
    @Published var isProcessing = false
    
    func convertToAudio() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let mapping = ImageToAudioConverter.ImageSoundMapping(
                brightnessToAmplitude: self.brightnessToAmplitude,
                colorToFrequency: self.colorToFrequency,
                spatialDistribution: self.spatialDistribution,
                textureGraininess: self.textureGraininess,
                baseFrequency: self.baseFrequency,
                frequencyRange: self.frequencyRange,
                duration: self.duration,
                harmonics: self.harmonics
            )
            
            let audioBuffer = ImageToAudioConverter.shared.convertImageToAudio(
                image: image,
                mapping: mapping
            )
            
            DispatchQueue.main.async {
                self.isProcessing = false
                if let buffer = audioBuffer {
                    AudioPlayerManager.shared.play(audioBuffer: buffer)
                }
            }
        }
    }
}

struct ImagePickerCamera: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerCamera
        
        init(_ parent: ImagePickerCamera) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }
    }
}

#Preview {
    ImageToAudioView()
}
