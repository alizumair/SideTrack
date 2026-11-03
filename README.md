# EdgeBar 🎛️

**EdgeBar** is an ultra-fast, native macOS utility that turns the outer edges of your MacBook trackpad and Apple Magic Trackpad into seamless, invisible hardware control strips.

Slide along the edges of your trackpad to smoothly adjust display brightness and volume with tactile haptic ticks, navigate browser tabs, scrub video timelines, capture interactive cropped screenshots, and record cropped screen regions with a floating Dynamic Island recording HUD — all without moving your mouse cursor or interfering with macOS native multi-finger scrolling and navigation gestures.

> 🎬 **Interactive Walkthrough & Simulator:** Try the gesture simulator live at [docs/walkthrough.html](docs/walkthrough.html) or in the app via **Menu Bar ➜ Feature Walkthrough & Guide...**

---

## ✨ Features

- **Direct Multitouch Contact Interception**: Dynamically links Apple's private `MultitouchSupport.framework` via `dlopen`. Processes contact frames directly at the hardware sensor layer with sub-millisecond responsiveness.
- **Intelligent Multi-Finger Gate**: Whenever two or more fingers touch the pad, EdgeBar immediately yields and passes through to macOS. Standard 2-finger scrolling, pinch-to-zoom, and 3/4-finger desktop swipes remain 100% unaffected.
- **Middle-Touch Rejection**: Contacts initiating outside designated edge strips (default: outer 10–18%) are strictly ignored for their entire lifespan, avoiding accidental activation while typing or navigating.
- **Synchronized Force Touch Haptics**: Uses `NSHapticFeedbackManager` to trigger tactile click ticks synchronized with scalar volume and brightness steps (16, 32, or 64 steps). Silent sliding by default, or optional subtle click sounds.
- **Cursor Freezing**: Automatically dissociates the hardware cursor position (`CGAssociateMouseAndMouseCursorPosition`) while sliding along an edge so your mouse cursor remains parked on screen.
- **Precision Modifiers**: Hold **Shift + Option (⇧⌥)** while sliding for quarter-step fine adjustment.
- **Context-Aware App Profiles**:
  - **Web Browsers (Chrome, Safari, Brave, Arc, Firefox, Edge)**: Bottom edge swipe cycles smoothly forward and backward through open tabs.
  - **Streaming & Video (YouTube, Netflix, Prime Video, QuickTime, IINA, VLC)**: Bottom edge automatically maps to video rewind and fast-forward scrub.
  - **Custom App Triggers**: Map macOS Shortcuts, AppleScripts, or shell commands to corner macros.
- **Corner Hold Macros with Visual Countdown Timer**:
  - **Bottom-Left Corner (1.5s)**: Triggers **Crop Screenshot** with interactive crosshairs and camera shutter sound.
  - **Bottom-Right Corner (3.0s)**: Triggers **Crop Screen Recording** with area drag selection and floating "Stop Recording" controller.
  - **Top-Right Corner**: Double-tap toggles system Mute instantly.
  - **Live Circular HUD**: Displays a 1... 2... 3... countdown HUD with synchronized haptic pulses during stationary corner holds.
- **Floating Dynamic Island Recording Controller**:
  - Displays live duration timer (`🔴 00:01`) and a floating **Stop Recording** button.
  - Graceful `SIGINT` finalization ensures video files are never corrupted.
- **Media Destination Manager**:
  - Customizable folder destination for screenshots and recordings directly in **Settings ➜ Extras Tab**.
  - Built-in "Choose Folder...", "Show in Finder", and "Reset to Default" actions.
  - Displays a clean pop-up HUD notification on save (`Saved to Documents`).
- **Native Monochrome Menu Bar Icon**:
  - Clean vector template status item depicting trackpad boundary and active edge controls.
  - Adapts automatically to macOS light mode, dark mode, accent colors, and menu selection highlights.
- **Zero Idle CPU Footprint**: Multitouch callbacks only fire when fingers make physical contact with the glass; 0% CPU consumption when idle.
- **Settings Persistence**: Configurations are stored as clean JSON in `UserDefaults` under key `io.github.edgebar.settings.v1`.

---

## 📐 Trackpad Layout & Gestures

```
+--------------------------------------------------------------+
| [ Left Edge (10%) ]                  [ Top-Right Corner ]   |
|   Slide Up / Down:                     Double-Tap: Mute      |
|   Display Brightness                                         |
|                                                              |
|                     Standard Trackpad Area                   |
|                   (Native macOS Navigation)                  |
|                                                              |
|                                         [ Right Edge (10%) ] |
|                                           Slide Up / Down:   |
|                                           System Volume      |
|                                                              |
| [ Bottom-Left Corner ]   [ Bottom Edge Strip (16%) ]  [ Bottom-Right Corner ]
|   Hold 1.5s: Screenshot    Browser: Switch Tabs         Hold 3.0s: Screen Rec
|   (Interactive Crop)       Video: Scrub Forward/Back   (Crop Area Recording)
|                            Double-Tap: Play / Pause  
+--------------------------------------------------------------+
```

| Zone | Primary Gesture | Secondary Gesture | Assigned Action |
| :--- | :--- | :--- | :--- |
| **Left Edge** | Vertical Slide | Hold `⇧⌥` | Smooth Display Brightness (Quarter-step precision) |
| **Right Edge** | Vertical Slide | Hold `⇧⌥` | Smooth System Volume (Quarter-step precision) |
| **Bottom Edge** | Horizontal Swipe | Double-Tap | Browser: Switch Tabs / Media: Skip Track / Tap: Play & Pause |
| **Top-Right Corner** | Double-Tap | — | Toggle System Mute |
| **Bottom-Left Corner** | Stationary Hold (1.5s) | — | Interactive Crop Screenshot (Area Selection) |
| **Bottom-Right Corner** | Stationary Hold (3.0s) | — | Interactive Crop Screen Recording (with Stop HUD) |

---

## 🏗️ Architecture & Project Structure

EdgeBar is organized into clean, decoupled layers adhering to professional macOS engineering standards:

```
EdgeBar/
├── Package.swift                             # Swift Package Manager manifest
├── Makefile                                  # Automation for build, install, and test
├── Resources/
│   ├── Info.plist                            # LSUIElement = true & Usage Descriptions
│   └── EdgeBar.entitlements                  # Sandbox entitlements
├── Sources/
│   └── EdgeBar/
│       ├── App/
│       │   ├── AppDelegate.swift             # App lifecycle & accessory configuration
│       │   ├── AppState.swift                # Central state coordinator & bus
│       │   └── Main.swift                    # Application entry point (@main)
│       ├── Core/
│       │   ├── Settings/
│       │   │   ├── SettingsModel.swift       # Codable configuration data structure
│       │   │   └── SettingsStore.swift       # JSON persistence & versioned migrations
│       │   ├── StateMachine/
│       │   │   ├── EdgeZone.swift            # Geometric classifier for edge strips & corners
│       │   │   ├── GestureState.swift        # Finite state definitions & tap tracking
│       │   │   ├── CornerHoldManager.swift   # Stationary corner hold detector & 1-2-3 timer
│       │   │   └── SlideEngine.swift         # Hardware gesture state machine & multi-finger gate
│       │   ├── Profiles/
│       │   │   └── ProfileManager.swift      # Contextual app detection (browsers, video apps)
│       │   └── Permissions/
│       │       └── AccessibilityManager.swift# TCC Accessibility check & polling
│       ├── Hardware/
│       │   ├── Multitouch/
│       │   │   ├── MultitouchBridge.swift    # dlopen wrapper for MultitouchSupport.framework
│       │   │   └── MultitouchTouch.swift     # Raw C ABI struct mapping & TrackpadContact
│       │   ├── Audio/
│       │   │   ├── CoreAudioBridge.swift     # AudioObjectSetPropertyData scalar volume & mute
│       │   │   └── MediaKeyDispatcher.swift  # Synthetic NX_KEYTYPE media key events
│       │   ├── Display/
│       │   │   └── DisplayBrightnessBridge.swift # DisplayServicesSetBrightness integration
│       │   ├── Haptics/
│       │   │   └── HapticFeedbackBridge.swift# NSHapticFeedbackManager tactile ticks
│       │   ├── Cursor/
│       │   │   └── CursorFreezer.swift       # CGAssociateMouseAndMouseCursorPosition toggling
│       │   ├── OSD/
│       │   │   ├── OSDBridge.swift           # Native macOS OSDManager bezel trigger
│       │   │   └── EdgeBarHUDOverlay.swift   # Custom translucent SwiftUI glass bezel
│       │   ├── ScreenRecording/
│       │   │   ├── ScreenRecordingManager.swift # QuickTime screencapture controller
│       │   │   └── ScreenSelectionOverlay.swift # Interactive crosshairs crop selector
│       │   └── MediaDestination/
│       │       └── MediaDestinationManager.swift# Media directory resolution & file naming
│       └── UI/
│           ├── MenuBar/
│           │   └── StatusBarController.swift # Native monochrome template status bar item
│           ├── Settings/
│           │   ├── SettingsView.swift        # Multi-tab settings container
│           │   ├── EdgesSettingsTab.swift    # Interactive visual trackpad map & dimensions
│           │   ├── FeelSettingsTab.swift     # Sensitivity, haptic steps, & tab switch feel
│           │   ├── ExtrasSettingsTab.swift   # Corner holds, capture styles, & media folder
│           │   ├── ProfilesSettingsTab.swift # App profile rules & custom scripts
│           │   └── GeneralSettingsTab.swift  # Launch at login & accessibility status
│           └── Onboarding/
│               └── OnboardingWindowController.swift # Accessibility onboarding window
└── Tests/
    └── EdgeBarTests/
        ├── SlideEngineTests.swift            # Unit test suite for multi-finger gate & gestures
        ├── SettingsModelTests.swift          # JSON encode/decode & store tests
        ├── CornerHoldTests.swift             # Corner hold gestures & timer tests
        ├── AdvancedFeaturesTests.swift       # Tab switching, media destinations & profiles
        └── EdgeZoneTests.swift               # Edge zone classification geometry tests
```

---

## 🚀 Building & Running

EdgeBar requires **macOS 13.0+** and **Xcode 14+** (or the standalone Swift toolchain).

### 1. Build and Install Application Bundle
```bash
make install
```
Compiles a release binary, structures the bundle at `build/EdgeBar.app`, code-signs the bundle with stable designated requirements, and installs it directly to `/Applications/EdgeBar.app`.

### 2. Launch the Application
```bash
make run
```
Builds the app bundle and opens `build/EdgeBar.app`. The EdgeBar trackpad icon will appear in your macOS menu bar.

### 3. Run Unit Tests
```bash
make test
```
Executes the comprehensive 42-test XCTest suite validating the `SlideEngine` state machine, multi-finger gate cancellation, middle touch rejection, modifier calculations, corner holds, media destinations, and JSON serialization.

---

## 🔒 Permissions

Because EdgeBar intercepts raw trackpad hardware frames and captures screens:

1. **Accessibility Permission**:
   - Required to detect physical multitouch contact frames.
   - On first launch, EdgeBar prompts to enable Accessibility under:  
     `System Settings` ➜ `Privacy & Security` ➜ `Accessibility`.
2. **Screen Recording Permission**:
   - Required when taking screenshots or screen recordings via corner holds.
   - Configured with `NSScreenCaptureUsageDescription` in `Info.plist` and stable designated code-signing requirements to ensure macOS remembers your approval permanently.

---

## 📄 License

EdgeBar is released under the **MIT License**.
