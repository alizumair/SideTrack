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
                
                // Corner Hold Macros
                VStack(alignment: .leading, spacing: 12) {
                    Text("Stationary Corner Hold Gestures")
                        .font(.subheadline.bold())
                    
                    Toggle("Enable Stationary Corner Holds", isOn: $settingsStore.settings.cornerHoldsEnabled)
                    
                    if settingsStore.settings.cornerHoldsEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Screenshot Hold (Left):")
                                    .frame(width: 175, alignment: .leading)
                                Slider(
                                    value: $settingsStore.settings.screenshotHoldDuration,
                                    in: 0.5...3.0,
                                    step: 0.1
                                )
                                Text(String(format: "%.1fs", settingsStore.settings.screenshotHoldDuration))
                                    .frame(width: 45, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            Text("Holding Top-Left or Bottom-Left stationary copies a screenshot to clipboard.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Recording Hold (Bottom-R):")
                                    .frame(width: 175, alignment: .leading)
                                Slider(
                                    value: $settingsStore.settings.screenRecordingHoldDuration,
                                    in: 1.0...5.0,
                                    step: 0.5
                                )
                                Text(String(format: "%.1fs", settingsStore.settings.screenRecordingHoldDuration))
                                    .frame(width: 45, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            Text("Holding Bottom-Right stationary opens macOS Screen Recording utility (Cmd+Shift+5).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    
                    Text("Stationary holds require a single finger in the outer 15% corner zones. Movement or lifting cancels immediately. Top-Right corner remains reserved for Mute.")
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
}
