# EdgeBar 🎛️

**EdgeBar** is an ultra-fast, native macOS utility app inspired by *SlideSense* that turns the outer edges of your MacBook trackpad (and Magic Trackpad) into seamless, invisible hardware control strips.

Slide up or down the edges of your trackpad to smoothly adjust display brightness and volume with tactile haptic ticks, swipe across the bottom edge to change music tracks, and double-tap the top-right corner to toggle system mute — all without moving your mouse cursor or interfering with macOS native multi-finger scrolling and gestures.

---

## ✨ Features

- **Direct Multitouch Contact Interception**: Dynamically links Apple's private `MultitouchSupport.framework` via `dlopen`. Bypasses sluggish `CGEventTap` APIs to process contact frames at the hardware sensor layer with zero latency.
- **Intelligent Multi-Finger Gate**: Whenever two or more fingers touch the pad, EdgeBar immediately yields and passes through to macOS. Standard 2-finger scrolling, pinch-to-zoom, and 3/4-finger desktop swipes remain 100% unaffected.
- **Middle-Touch Rejection**: Contacts initiating outside designated edge strips (default: outer 18%) are strictly ignored for their entire lifespan, avoiding accidental activation while typing or navigating.
- **Synchronized Force Touch Haptics**: Uses `NSHapticFeedbackManager` to trigger tactile click ticks synchronized with scalar volume and brightness steps (16, 32, or 64 steps).
- **Cursor Freezing**: Automatically dissociates the hardware cursor position (`CGAssociateMouseAndMouseCursorPosition`) while sliding along an edge so your mouse cursor remains parked on screen.
- **Precision Modifiers**: Hold **Shift + Option (⇧⌥)** while sliding for quarter-step fine adjustment.
- **Direct System Hardware Bridges**:
  - **Volume**: Native CoreAudio API (`AudioObjectSetPropertyData`) with stereo-channel fallback and mute controls.
  - **Brightness**: Private `DisplayServices.framework` (`DisplayServicesSetBrightness`) with key-event fallback.
  - **OSD Integration**: Directly commands macOS native bezel overlays (`OSDManager`) or EdgeBar's custom floating frosted-glass HUD.
- **Pure Swift Architecture**: SwiftUI for the multi-tab settings panel; AppKit for low-level system services.
- **Zero Idle CPU Footprint**: Multitouch callbacks only fire when fingers make physical contact with the glass; 0% CPU consumption when idle.
- **Settings Persistence**: Configurations are stored as clean JSON in `UserDefaults` under key `io.github.edgebar.settings.v1`.

---

## 📐 Trackpad Layout & Gestures

```
+--------------------------------------------------------------+
| [ Left Edge (18%) ]                  [ Top-Right Corner ]   |
|   Slide Up / Down:                     Double-Tap: Mute      |
|   Display Brightness                                         |
|                                                              |
|                     Standard Trackpad Area                   |
|                   (Native macOS Navigation)                  |
|                                                              |
|                                         [ Right Edge (18%) ] |
|                                           Slide Up / Down:   |
|                                           System Volume      |
|                                                              |
|               [ Bottom Edge Strip (18%) ]                    |
|          Horizontal Swipe: Next / Previous Track             |
|                Double-Tap: Play / Pause                      |
+--------------------------------------------------------------+
```

| Zone | Primary Gesture | Secondary Gesture | Assigned Action |
| :--- | :--- | :--- | :--- |
| **Left Edge** | Vertical Slide | Hold `⇧⌥` | Smooth Display Brightness (Quarter-step precision) |
| **Right Edge** | Vertical Slide | Hold `⇧⌥` | Smooth System Volume (Quarter-step precision) |
| **Bottom Edge** | Horizontal Swipe | Double-Tap | Swipe: Skip Track / Tap: Play & Pause |
| **Top-Right Corner** | Double-Tap | — | Toggle System Mute |

---

## 🏗️ Architecture & Project Structure

EdgeBar is organized into clean, decoupled layers adhering to professional macOS engineering standards:

```
EdgeBar/
├── Package.swift                             # Swift Package Manager manifest
├── Makefile                                  # Automation for build, run, and test
├── Resources/
│   ├── Info.plist                            # LSUIElement = true (Menu-bar-only)
│   └── EdgeBar.entitlements                  # Sandbox entitlements
├── scripts/
│   └── setup_github_repo.sh                  # One-click GitHub CLI publishing script
├── Sources/
│   └── EdgeBar/
│       ├── App/
│       │   ├── AppDelegate.swift             # App lifecycle & accessory configuration
│       │   ├── AppState.swift                # Central state coordinator & bus
│       │   └── Main.swift                    # Application entry point (@main)
│       ├── Core/
│       │   ├── Settings/
│       │   │   ├── SettingsModel.swift       # Codable configuration data structure
│       │   │   └── SettingsStore.swift       # JSON persistence under io.github.edgebar.settings.v1
│       │   ├── StateMachine/
│       │   │   ├── EdgeZone.swift            # Geometric classifier for edge strips & corners
│       │   │   ├── GestureState.swift        # Finite state definitions & tap tracking
│       │   │   └── SlideEngine.swift         # Hardware gesture state machine & multi-finger gate
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
│       │   └── OSD/
│       │       ├── OSDBridge.swift           # Native macOS OSDManager bezel trigger
│       │       └── EdgeBarHUDOverlay.swift   # Custom translucent SwiftUI glass bezel
│       └── UI/
│           ├── MenuBar/
│           │   └── StatusBarController.swift # NSStatusItem with live readouts & controls
│           ├── Settings/
│           │   ├── SettingsView.swift        # Multi-tab settings container
│           │   ├── EdgesSettingsTab.swift    # Interactive visual trackpad map & dimensions
│           │   ├── FeelSettingsTab.swift     # Sensitivity, haptic steps, & axis inversion
│           │   ├── ExtrasSettingsTab.swift   # Precision modifiers & HUD configuration
│           │   └── GeneralSettingsTab.swift  # Launch at login & accessibility status
│           └── Onboarding/
│               └── OnboardingWindowController.swift # Accessibility onboarding window
└── Tests/
    └── EdgeBarTests/
        ├── SlideEngineTests.swift            # Unit test suite for multi-finger gate & gestures
        ├── SettingsModelTests.swift          # JSON encode/decode & store tests
        └── EdgeZoneTests.swift               # Edge zone classification geometry tests
```

---

## 🚀 Building & Running

EdgeBar requires **macOS 13.0+** and **Xcode 14+** (or the standalone Swift toolchain).

### 1. Build Application Bundle
```bash
make app
```
Compiles a release binary, structures the bundle at `build/EdgeBar.app`, copies `Info.plist`, and applies an ad-hoc code-signature.

### 2. Launch the Application
```bash
make run
```
Builds the app bundle and opens `build/EdgeBar.app`. The EdgeBar slider icon will appear in your macOS menu bar.

### 3. Run Unit Tests
```bash
make test
```
Executes the comprehensive XCTest suite validating the `SlideEngine` state machine, multi-finger gate cancellation, middle touch rejection, modifier calculations, and JSON serialization.

---

## 🔒 Granting Permissions

Because EdgeBar intercepts raw trackpad hardware frames:

1. When first launched, EdgeBar will display the **Permissions Onboarding Window**.
2. Click **Grant Accessibility Permission** (or navigate manually to:  
   `System Settings` ➜ `Privacy & Security` ➜ `Accessibility`).
3. Toggle the switch next to **EdgeBar** to ON.
4. EdgeBar will automatically detect the permission change and activate the trackpad listener.

---

## 🌐 Publishing to GitHub

To publish this project to GitHub using the GitHub CLI (`gh`):

### Option A: Using the Automated Script
```bash
# Create and push to a public repository named EdgeBar
./scripts/setup_github_repo.sh EdgeBar --public
```

### Option B: Manual Terminal Commands
```bash
# 1. Initialize local repository
git init
git branch -M main

# 2. Stage and commit all files
git add .
git commit -m "Initial commit: EdgeBar native macOS trackpad hardware strips"

# 3. Create repository and push using GitHub CLI
gh repo create EdgeBar --public --source=. --remote=origin --push
```

---

## 📄 License

EdgeBar is released under the **MIT License**.
