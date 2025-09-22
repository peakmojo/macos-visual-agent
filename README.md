# Visual Agent - macOS Desktop App

A macOS desktop overlay app that monitors screen activity and allows team members to see each other's work status in real-time.

## Features

- **Overlay Interface**: Minimal, always-on-top interface that doesn't interfere with work
- **Screen Monitoring**: Captures screenshots, mouse movements, and keystrokes (with permissions)
- **Buddy System**: Shows team members and their current status (watching, taking a break, disabled)
- **Real-time Status**: Visual indicators for each team member's activity
- **Database Persistence**: SQLite database for storing buddy information and activity logs
- **Privacy Controls**: Individual buddies can be disabled from monitoring

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later (for building)
- Screen Recording permission
- Accessibility permission (for keystroke monitoring)

## Building the App

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd visual-agent
   ```

2. **Build using the script:**
   ```bash
   ./build.sh
   ```

3. **Or build manually with Xcode:**
   ```bash
   xcodebuild build -project VisualAgent.xcodeproj -scheme VisualAgent -configuration Release
   ```

## Running the App

1. **Grant Permissions:**
   - When first launched, the app will request Screen Recording and Accessibility permissions
   - Go to System Preferences → Security & Privacy → Privacy
   - Enable permissions for Visual Agent under "Screen Recording" and "Accessibility"

2. **Launch the App:**
   - The app appears as an overlay in the top-right corner of your screen
   - A status bar icon (👥) allows you to show/hide the overlay
   - Click the chevron to expand/collapse the buddy list

## Usage

- **Expand/Collapse**: Click the chevron button to show/hide the full buddy list
- **Enable/Disable Monitoring**: Hover over a buddy and click the eye icon to toggle monitoring
- **Status Indicators**: 
  - Blue dot: Currently watching your screen
  - Orange dot: Taking a break
  - Gray dot: Monitoring disabled
- **Settings**: Click the gear icon for additional options

## File Structure

```
visual-agent/
├── VisualAgentApp.swift    # Main app entry point
├── ContentView.swift       # Main UI components
├── ScreenMonitor.swift     # Screen monitoring functionality
├── DatabaseManager.swift   # SQLite database operations
├── VisualAgent.xcodeproj/  # Xcode project files
├── VisualAgent.entitlements # App permissions
├── Info.plist             # App configuration
├── build.sh               # Build script
└── README.md              # This file
```

## Privacy & Security

- All screen monitoring is local and stored in a local SQLite database
- No data is transmitted over the network without explicit user consent
- Users have full control over when monitoring is active
- Individual buddies can be disabled at any time

## Development

To contribute or modify the app:

1. Open `VisualAgent.xcodeproj` in Xcode
2. Make your changes
3. Test thoroughly, especially permission handling
4. Build and run using Xcode or the build script

## Permissions Explained

- **Screen Recording**: Required to capture screenshots for productivity monitoring
- **Accessibility**: Required to monitor keyboard input for activity tracking
- **Camera/Microphone**: Future features (currently unused)

The app is designed with privacy in mind and only collects data necessary for the productivity monitoring features.