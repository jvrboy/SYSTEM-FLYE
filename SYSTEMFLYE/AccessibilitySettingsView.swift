import SwiftUI

struct AccessibilitySettingsView: View {
    @State private var voiceOverEnabled = false
    @State private var zoomEnabled = true
    @State private var zoomLevel: Double = 2.0
    @State private var reduceMotion = false
    @State private var reduceTransparency = false
    @State private var invertColors = false
    @State private var colorFilters = false
    @State private var boldText = false
    @State private var buttonShapes = true
    @State private var onOffLabels = true
    @State private var grayscale: Double = 0.0
    @State private var redGreenFilter = false
    @State private var greenRedFilter = false
    @State private var blueYellowFilter = false
    @State private var increaseContrast = false
    @State private var reduceWhitePoint = false
    @State private var switchControlEnabled = false
    @State private var assistiveTouchEnabled = false
    @State private var liveCaptionsEnabled = false
    @State private var soundRecognitionEnabled = false
    @State private var textSize: DynamicTypeSize = .large
    @State private var boldTextSize: Bool = false
    @State private var showingAccessibilityShortcut = false
    @State private var activeTab: AccessibilityTab = .vision
    @State private var hapticFeedbackEnabled = true
    @State private var audioDescriptionsEnabled = true
    @State private var monoAudioEnabled = false
    @State private var balanceLeftRight: Double = 0.0
    @State private var showClosedCaptions = true
    @State private var captionStyle: CaptionStyle = .default
    @State private var hearingDeviceCompatibility = false
    @State private var customVibrationEnabled = false
    @State private var shakeToUndo = true
    @State private var shakeToRedo = false

    enum AccessibilityTab: String, CaseIterable { case vision = "Vision"; case hearing = "Hearing"; case motor = "Motor"; case general = "General" }
    enum CaptionStyle: String, CaseIterable { case `default` = "Default"; case largeText = "Large Text"; case highContrast = "High Contrast"; case monochrome = "Monochrome" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accessibility").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                        Text("Customize accessibility features").font(.system(size: 14, weight: .regular)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)

                    Divider().background(SystemFlyeTheme.line)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AccessibilityTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { activeTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(activeTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(activeTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch activeTab {
                    case .vision: visionSettings
                    case .hearing: hearingSettings
                    case .motor: motorSettings
                    case .general: generalSettings
                    }
                }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
            .navigationTitle("Accessibility").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAccessibilityShortcut) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Accessibility Shortcut").font(.title.weight(.bold)).foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Triple-click the side button to quickly access accessibility features.").font(.subheadline).foregroundStyle(.secondary)
                            VStack(spacing: 12) {
                                AccessibilityShortcutOption(title: "VoiceOver", icon: "eye.fill", isSelected: voiceOverEnabled)
                                AccessibilityShortcutOption(title: "Zoom", icon: "magnifyingglass", isSelected: zoomEnabled)
                                AccessibilityShortcutOption(title: "AssistiveTouch", icon: "hand.tap.fill", isSelected: assistiveTouchEnabled)
                                AccessibilityShortcutOption(title: "Switch Control", icon: "switch.2", isSelected: switchControlEnabled)
                                AccessibilityShortcutOption(title: "Guided Access", icon: "lock.fill", isSelected: false)
                            }
                        }
                        Spacer()
                    }
                    .padding(20).background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
                    .navigationTitle("Shortcut").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showingAccessibilityShortcut = false } } }
                }
            }
        }
    }

    private var visionSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "eye.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("VISION").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "VoiceOver", subtitle: "Screen reader for visually impaired users", isOn: $voiceOverEnabled)
                    ToggleRow(title: "Zoom", subtitle: "Magnify content up to 15x", isOn: $zoomEnabled)
                    HStack { Text("Zoom Level").font(.caption).foregroundColor(.secondary); Spacer(); Slider(value: $zoomLevel, in: 1.0...15.0, step: 0.5).tint(SystemFlyeTheme.cyan); Text("\(Int(zoomLevel))x").font(.caption.monospacedDigit()).foregroundColor(SystemFlyeTheme.cyan).frame(width: 35) }
                    ToggleRow(title: "Reduce Motion", subtitle: "Minimize animations and parallax", isOn: $reduceMotion)
                    ToggleRow(title: "Reduce Transparency", subtitle: "Increase contrast by reducing blur", isOn: $reduceTransparency)
                    ToggleRow(title: "Increase Contrast", subtitle: "Make text and content more distinct", isOn: $increaseContrast)
                    ToggleRow(title: "Bold Text", subtitle: "Increase font weight", isOn: $boldText)
                    ToggleRow(title: "Button Shapes", subtitle: "Add shapes to buttons", isOn: $buttonShapes)
                    ToggleRow(title: "On/Off Labels", subtitle: "Show labels for on/off switches", isOn: $onOffLabels)
                    ToggleRow(title: "Reduce White Point", subtitle: "Dim white colors", isOn: $reduceWhitePoint)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "textformat").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("DISPLAY & TEXT").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text Size").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Picker("", selection: $textSize) { ForEach(DynamicTypeSize.allCases, id: \.self) { size in Text(sizeLabel(for: size)).tag(size) } }
                        .pickerStyle(.segmented)
                    }
                    ToggleRow(title: "Bold Text", subtitle: "Increase text weight globally", isOn: $boldTextSize)
                    HStack { Text("Grayscale").font(.caption).foregroundColor(.secondary); Spacer(); Slider(value: $grayscale, in: 0...1).tint(.gray); Text("\(Int(grayscale * 100))%").font(.caption.monospacedDigit()).foregroundColor(.gray).frame(width: 35) }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "eye.trianglebadge.exclamationmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("COLOR FILTERS").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "Color Filters", subtitle: "Apply filters for color blindness", isOn: $colorFilters)
                    if colorFilters {
                        VStack(spacing: 12) {
                            FilterToggleRow(title: "Red/Green", color: .red, isOn: $redGreenFilter)
                            FilterToggleRow(title: "Green/Red", color: .green, isOn: $greenRedFilter)
                            FilterToggleRow(title: "Blue/Yellow", color: .blue, isOn: $blueYellowFilter)
                        }
                        .padding(.top, 8)
                    }
                    ToggleRow(title: "Invert Colors", subtitle: "Invert display colors", isOn: $invertColors)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }

            Button { showingAccessibilityShortcut = true }
                label: {
                    HStack { Text("Accessibility Shortcut").font(.subheadline.weight(.semibold)).foregroundColor(.blue); Spacer(); Text("Triple-click side button").font(.subheadline).foregroundColor(.gray); Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray) }
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
        }
    }

    private var hearingSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "ear.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("HEARING").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "Live Captions", subtitle: "Transcribe audio in real time", isOn: $liveCaptionsEnabled)
                    ToggleRow(title: "Sound Recognition", subtitle: "Identify surrounding sounds", isOn: $soundRecognitionEnabled)
                    ToggleRow(title: "Audio Descriptions", subtitle: "Narrate video content", isOn: $audioDescriptionsEnabled)
                    ToggleRow(title: "Mono Audio", subtitle: "Combine stereo channels", isOn: $monoAudioEnabled)
                    if monoAudioEnabled {
                        HStack { Text("Left/Right Balance").font(.caption).foregroundColor(.secondary); Spacer(); Slider(value: $balanceLeftRight, in: -1...1).tint(SystemFlyeTheme.cyan); Text(String(format: "%.0f", balanceLeftRight * 100)).font(.caption.monospacedDigit()).foregroundColor(SystemFlyeTheme.cyan).frame(width: 30) }.padding(.horizontal, 4)
                    }
                    ToggleRow(title: "Hearing Device Compatibility", subtitle: "Enable Bluetooth hearing aids", isOn: $hearingDeviceCompatibility)
                    ToggleRow(title: "Closed Captions + SDH", subtitle: "Show captions and subtitles", isOn: $showClosedCaptions)
                    if showClosedCaptions {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caption Style").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            Picker("", selection: $captionStyle) { ForEach(CaptionStyle.allCases) { style in Text(style.rawValue).tag(style) } }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private var motorSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "hand.tap.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("PHYSICAL & MOTOR").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "Switch Control", subtitle: "Navigate with adaptive switches", isOn: $switchControlEnabled)
                    ToggleRow(title: "AssistiveTouch", subtitle: "Customizable touch gestures", isOn: $assistiveTouchEnabled)
                    ToggleRow(title: "Haptic Feedback", subtitle: "Vibrate on interactions", isOn: $hapticFeedbackEnabled)
                    ToggleRow(title: "Custom Vibration", subtitle: "Create custom vibration patterns", isOn: $customVibrationEnabled)
                    ToggleRow(title: "Shake to Undo", subtitle: "Shake device to undo", isOn: $shakeToUndo)
                    ToggleRow(title: "Shake to Redo", subtitle: "Shake device to redo", isOn: $shakeToRedo)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "gearshape.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("GENERAL").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "Prefer Accessibility", subtitle: "Prioritize accessibility features", isOn: .constant(true))
                    ToggleRow(title: "Auto-Enable Features", subtitle: "Automatically enable recommended settings", isOn: .constant(false))
                    ToggleRow(title: "Accessibility Shortcut", subtitle: "Triple-click side button", isOn: .constant(true))
                    ToggleRow(title: "Accessibility Inspector", subtitle: "Enable developer inspector", isOn: .constant(false))
                    ToggleRow(title: "AssistiveTouch Waiting", subtitle: "Show menu when idle", isOn: .constant(false))
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private func sizeLabel(for size: DynamicTypeSize) -> String {
        switch size { case .xSmall: return "XS"; case .small: return "S"; case .medium: return "M"; case .large: return "L"; case .xLarge: return "XL"; case .xxLarge: return "XXL"; case .xxxLarge: return "XXXL"; case .accessibility1: return "A1"; case .accessibility2: return "A2"; case .accessibility3: return "A3"; case .accessibility4: return "A4"; case .accessibility5: return "A5"; default: return "L" }
    }
}

struct FilterToggleRow: View {
    let title: String
    let color: Color
    @Binding var isOn: Bool
    var body: some View {
        Toggle { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white) } onToggled: { }
            toggleStyle: .checkbox
            .tint(color)
            .padding(.horizontal, 4)
    }
}

struct AccessibilityShortcutOption: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(isSelected ? SystemFlyeTheme.cyan : .secondary).frame(width: 24)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Spacer()
            if isSelected { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) }
        }
        .padding(14)
        .background(isSelected ? SystemFlyeTheme.cyan.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? SystemFlyeTheme.cyan.opacity(0.3) : SystemFlyeTheme.line))
    }
}

struct AccessibilitySettingsView_Previews: PreviewProvider {
    static var previews: some View { AccessibilitySettingsView().preferredColorScheme(.dark) }
}

