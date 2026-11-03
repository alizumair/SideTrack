import SwiftUI

public struct ExtrasSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var testScriptResult: String? = nil
    @State private var isRunningTest: Bool = false
    
    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Modifiers, Scripts & Shortcuts")
                    .font(.headline)
                
                // Precision Modifier
                VStack(alignment: .leading, spacing: 8) {
                    Text("Precision Modifiers (⇧⌥)")
                        .font(.subheadline.bold())
                    
                    HStack {
                        Text("Precision Rate:")
                            .frame(width: 140, alignment: .leading)
                        Slider(
                            value: $settingsStore.settings.precisionMultiplier,
                            in: 0.10...0.50,
                            step: 0.05
                        )
                        Text("\(Int(settingsStore.settings.precisionMultiplier * 100))%")
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                    Text("Hold Shift + Option (⇧⌥) while sliding for micro-adjustments and fine tuning.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Double-Tap Shortcuts
                VStack(alignment: .leading, spacing: 12) {
                    Text("Corner & Tap Shortcuts")
                        .font(.subheadline.bold())
                    
                    Picker("Top-Right Corner Double-Tap:", selection: $settingsStore.settings.topRightCornerAction) {
                        ForEach(CornerAction.allCases) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Bottom Edge Double-Tap:", selection: $settingsStore.settings.bottomDoubleTapAction) {
                        ForEach(CornerAction.allCases) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Divider()
                
                // Scripting & Custom Triggers
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom Script & Shortcut Trigger")
                        .font(.subheadline.bold())
                    
                    Picker("Trigger Execution Engine:", selection: $settingsStore.settings.customScriptTrigger.type) {
                        ForEach(ScriptTriggerType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(settingsStore.settings.customScriptTrigger.type == .shortcut ? "Shortcut Name:" : "Script Command / Body:")
                            .font(.caption.bold())
                        
                        if settingsStore.settings.customScriptTrigger.type == .shortcut {
                            TextField("e.g. Turn On Focus Mode", text: $settingsStore.settings.customScriptTrigger.payload)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextEditor(text: $settingsStore.settings.customScriptTrigger.payload)
                                .font(.system(.caption, design: .monospaced))
                                .frame(height: 70)
                                .border(Color.secondary.opacity(0.2), width: 1)
                        }
                    }
                    
                    HStack {
                        Button(action: runTestScript) {
                            HStack(spacing: 6) {
                                if isRunningTest {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text("Test Execute")
                            }
                        }
                        .disabled(isRunningTest || settingsStore.settings.customScriptTrigger.payload.isEmpty)
                        
                        if let res = testScriptResult {
                            Text(res)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Text("Map 'Run Custom Script' to any edge double-tap or corner macro above to trigger this action on the fly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Corner Hold Macros & Gestures
                VStack(alignment: .leading, spacing: 14) {
                    Text("Stationary Corner Hold Gestures")
                        .font(.subheadline.bold())
                    
                    Toggle("Enable Stationary Corner Holds", isOn: $settingsStore.settings.cornerHoldsEnabled)
                    
                    if settingsStore.settings.cornerHoldsEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Show Visual Countdown Timer (1, 2, 3...)", isOn: $settingsStore.settings.showHoldCountdownTimer)
                                .font(.body)
                            Text("Displays a live circular countdown HUD with synchronized haptic ticks while holding.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            // Corner Action Mappings
                            Text("Corner Hold Actions")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Bottom-Left Corner:")
                                    .frame(width: 170, alignment: .leading)
                                Picker("", selection: $settingsStore.settings.bottomLeftHoldAction) {
                                    ForEach(CornerHoldAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            HStack {
                                Text("Bottom-Right Corner:")
                                    .frame(width: 170, alignment: .leading)
                                Picker("", selection: $settingsStore.settings.bottomRightHoldAction) {
                                    ForEach(CornerHoldAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            HStack {
                                Text("Top-Left Corner:")
                                    .frame(width: 170, alignment: .leading)
                                Picker("", selection: $settingsStore.settings.topLeftHoldAction) {
                                    ForEach(CornerHoldAction.allCases) { action in
                                        Text(action.rawValue).tag(action)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Divider()
                            
                            // Execution Modes
                            Text("Execution Modes")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Screenshot Style:")
                                        .frame(width: 170, alignment: .leading)
                                    Picker("", selection: $settingsStore.settings.screenshotMode) {
                                        ForEach(ScreenshotMode.allCases) { mode in
                                            Text(mode.rawValue).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    
                                    Button("Test Screenshot") {
                                        AppState.shared.slideEngineDidTriggerScreenshot()
                                    }
                                    .controlSize(.small)
                                }
                                Text("Crop Screen displays an area selection crosshair to drag and capture any window or region with dimensions badge.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Recording Style:")
                                        .frame(width: 170, alignment: .leading)
                                    Picker("", selection: $settingsStore.settings.recordingMode) {
                                        ForEach(ScreenRecordingMode.allCases) { mode in
                                            Text(mode.rawValue).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    
                                    Button("Test Recording") {
                                        AppState.shared.slideEngineDidTriggerScreenRecording()
                                    }
                                    .controlSize(.small)
                                }
                                Text("Crop Screen lets you drag an area to record with live dimensions, followed by a floating 'Stop Recording' HUD.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            // Durations
                            Text("Hold Durations")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Screenshot Hold:")
                                    .frame(width: 170, alignment: .leading)
                                Slider(
                                    value: $settingsStore.settings.screenshotHoldDuration,
                                    in: 0.5...3.5,
                                    step: 0.1
                                )
                                Text(String(format: "%.1fs", settingsStore.settings.screenshotHoldDuration))
                                    .frame(width: 45, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            
                            HStack {
                                Text("Recording Hold:")
                                    .frame(width: 170, alignment: .leading)
                                Slider(
                                    value: $settingsStore.settings.screenRecordingHoldDuration,
                                    in: 1.0...5.0,
                                    step: 0.5
                                )
                                Text(String(format: "%.1fs", settingsStore.settings.screenRecordingHoldDuration))
                                    .frame(width: 45, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            
                            HStack {
                                Text("Corner Zone Size:")
                                    .frame(width: 170, alignment: .leading)
                                Slider(
                                    value: $settingsStore.settings.cornerHoldFraction,
                                    in: 0.10...0.25,
                                    step: 0.01
                                )
                                Text(String(format: "%.0f%%", settingsStore.settings.cornerHoldFraction * 100))
                                    .frame(width: 45, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            
                            Divider()
                            
                            // Save Destination (Screenshots & Recordings)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Save Destination (Screenshots & Screen Recordings)")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                
                                let currentDir = MediaDestinationManager.effectiveMediaDirectory(settings: settingsStore.settings)
                                let folderName = MediaDestinationManager.folderDisplayName(for: currentDir)
                                let isCustom = !settingsStore.settings.customMediaSaveDirectory.isEmpty
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .font(.title2)
                                        .foregroundColor(.accentColor)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(folderName)
                                                .font(.subheadline.bold())
                                            if isCustom {
                                                Text("Custom")
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .foregroundColor(.accentColor)
                                                    .clipShape(Capsule())
                                            } else {
                                                Text("macOS System Default")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Text(currentDir.path)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(8)
                                
                                HStack(spacing: 10) {
                                    Button("Choose Folder...") {
                                        selectFolder()
                                    }
                                    
                                    if isCustom {
                                        Button("Reset to Default") {
                                            settingsStore.settings.customMediaSaveDirectory = ""
                                        }
                                    }
                                    
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: currentDir.path)
                                    }
                                }
                                
                                Text("All screenshots and screen recordings are saved to this folder, and a pop-up confirmation displays the folder name whenever one is taken.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    Text("Top-Right corner remains reserved for double-tap Mute.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
    
    private func runTestScript() {
        isRunningTest = true
        testScriptResult = "Running..."
        ScriptDispatcher.shared.execute(trigger: settingsStore.settings.customScriptTrigger) { result in
            DispatchQueue.main.async {
                self.isRunningTest = false
                switch result {
                case .success(let output):
                    self.testScriptResult = "✓ \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
                case .failure(let err):
                    self.testScriptResult = "✗ \(err.localizedDescription)"
                }
            }
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        panel.message = "Choose destination folder for screenshots and recordings"
        if panel.runModal() == .OK, let url = panel.url {
            settingsStore.settings.customMediaSaveDirectory = url.path
        }
    }
}
