import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.12, green: 0.08, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Advanced Sound Designer")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foreground(Color.white)
                    
                    Text("Professional granular synthesis & image-to-audio conversion")
                        .font(.system(size: 13, weight: .regular))
                        .foreground(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.15, green: 0.12, blue: 0.2),
                            Color(red: 0.1, green: 0.1, blue: 0.15)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    SynthesizerView()
                        .tag(0)
                    
                    ImageToAudioView()
                        .tag(1)
                    
                    ExportView()
                        .tag(2)
                    
                    FileManagerView()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Tab Navigation
                HStack(spacing: 0) {
                    TabBarButton(
                        icon: "waveform",
                        label: "Synthesizer",
                        isSelected: selectedTab == 0
                    ) {
                        selectedTab = 0
                    }
                    
                    TabBarButton(
                        icon: "photo",
                        label: "Image→Audio",
                        isSelected: selectedTab == 1
                    ) {
                        selectedTab = 1
                    }
                    
                    TabBarButton(
                        icon: "arrow.up.doc",
                        label: "Export",
                        isSelected: selectedTab == 2
                    ) {
                        selectedTab = 2
                    }
                    
                    TabBarButton(
                        icon: "folder.fill",
                        label: "Files",
                        isSelected: selectedTab == 3
                    ) {
                        selectedTab = 3
                    }
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.12))
                .frame(height: 60)
            }
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color.white.opacity(0.5))
        }
    }
}

#Preview {
    ContentView()
}
