import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    
    public init(settingsStore: SettingsStore = .shared) {
        self.settingsStore = settingsStore
    }
    
    public var body: some View {
        TabView {
            EdgesSettingsTab(settingsStore: settingsStore)
                .tabItem {
                    Label("Edges", systemImage: "rectangle.split.3x1")
                }
            
            FeelSettingsTab(settingsStore: settingsStore)
                .tabItem {
                    Label("Feel", systemImage: "hand.tap")
                }
            
            ExtrasSettingsTab(settingsStore: settingsStore)
                .tabItem {
                    Label("Extras", systemImage: "sparkles")
                }
            
            GeneralSettingsTab(settingsStore: settingsStore)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 580, height: 480)
    }
}
