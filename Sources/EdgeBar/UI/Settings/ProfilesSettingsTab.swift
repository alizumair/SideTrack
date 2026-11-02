import SwiftUI

public struct ProfilesSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var profileManager = ProfileManager.shared
    
    @State private var showingAddSheet: Bool = false
    @State private var newProfileName: String = ""
    @State private var newProfileBundleID: String = ""
    @State private var newProfileScrubMode: BottomScrubMode = .timelineScrub
    
    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("App-Specific Context Profiles")
                    .font(.headline)
                
                // Game Mode / Full-Screen Bypass
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable Game Mode (Full-Screen Bypass)", isOn: $settingsStore.settings.gameModeEnabled)
                        .font(.subheadline.bold())
                    
                    Text("Automatically suspends edge touch tracking whenever a full-screen game or immersive application is focused.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if profileManager.isGameModeActive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Full-screen app detected: EdgeBar is currently bypassed.")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Divider()
                
                // Active Frontmost App Status Card
                HStack(spacing: 12) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Foreground Application")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(profileManager.frontmostAppName.isEmpty ? "Finder" : profileManager.frontmostAppName)
                            .font(.subheadline.bold())
                        Text(profileManager.frontmostBundleID.isEmpty ? "com.apple.finder" : profileManager.frontmostBundleID)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let active = profileManager.activeProfile {
                        Text("Active Profile: \(active.name)")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            .foregroundColor(.accentColor)
                    } else {
                        Text("Default Profile")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                
                Divider()
                
                // Profiles List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Configured Context Profiles")
                            .font(.subheadline.bold())
                        Spacer()
                        Button(action: {
                            newProfileName = profileManager.frontmostAppName.isEmpty ? "Custom App" : profileManager.frontmostAppName
                            newProfileBundleID = profileManager.frontmostBundleID
                            showingAddSheet = true
                        }) {
                            Label("Add Profile", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    ForEach($settingsStore.settings.profiles) { $profile in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle(isOn: $profile.isEnabled) {
                                    Text(profile.name)
                                        .font(.body.weight(.medium))
                                }
                                Spacer()
                                Button(action: {
                                    deleteProfile(id: profile.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text("Bundle IDs: \(profile.bundleIdentifier)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Bottom Strip Mode:")
                                    .font(.caption)
                                Picker("", selection: $profile.bottomScrubMode) {
                                    ForEach(BottomScrubMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 220)
                            }
                        }
                        .padding(12)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showingAddSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add Context Profile")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile Name:")
                        .font(.caption.bold())
                    TextField("e.g. Logic Pro / Ableton", text: $newProfileName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bundle Identifier(s) (comma separated):")
                        .font(.caption.bold())
                    TextField("e.g. com.apple.logic10", text: $newProfileBundleID)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bottom Strip Action:")
                        .font(.caption.bold())
                    Picker("", selection: $newProfileScrubMode) {
                        ForEach(BottomScrubMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingAddSheet = false
                    }
                    Button("Save Profile") {
                        let newP = AppProfile(
                            name: newProfileName,
                            bundleIdentifier: newProfileBundleID,
                            bottomEdgeAction: newProfileScrubMode == .timelineScrub ? .timelineScrub : (newProfileScrubMode == .pageScroll ? .scroll : .mediaTrack),
                            bottomScrubMode: newProfileScrubMode
                        )
                        settingsStore.settings.profiles.append(newP)
                        showingAddSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newProfileName.isEmpty || newProfileBundleID.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 420)
        }
    }
    
    private func deleteProfile(id: UUID) {
        settingsStore.settings.profiles.removeAll { $0.id == id }
    }
}
