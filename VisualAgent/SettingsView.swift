import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showingResetAlert = false
    @State private var warnings: [String] = []
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.05))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - Feature Toggles Section
                    SettingsSection(title: "Features", icon: "switch.2") {
                        FeatureToggle(
                            title: "Screen Capture (Eye Feature)",
                            description: "Monitor screen activity, extract text, and analyze UI elements",
                            isOn: $settings.screenCaptureEnabled,
                            icon: "eye.fill",
                            color: .blue,
                            requiresPermission: "Screen Recording"
                        )

                        FeatureToggle(
                            title: "Message Monitoring",
                            description: "Monitor iMessage and WeChat notifications",
                            isOn: $settings.messageMonitoringEnabled,
                            icon: "message.fill",
                            color: .green,
                            requiresPermission: "Accessibility"
                        )
                    }

                    // MARK: - Screen Capture Settings
                    if settings.screenCaptureEnabled {
                        SettingsSection(title: "Screen Capture Options", icon: "camera.fill") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Capture Rate:")
                                    Spacer()
                                    Text("\(Int(settings.screenCaptureFPS)) FPS")
                                        .foregroundColor(.secondary)
                                }

                                Slider(value: $settings.screenCaptureFPS, in: 0.5...5, step: 0.5)

                                Toggle("Extract Text (OCR)", isOn: $settings.enableTextExtraction)
                                Toggle("Analyze UI Elements", isOn: $settings.enableAccessibilityAnalysis)
                                Toggle("Save Screenshots", isOn: $settings.saveScreenshots)
                                    .help("Store screen captures to disk (privacy risk)")
                            }
                        }
                    }

                    // MARK: - Message Processing Settings
                    if settings.messageMonitoringEnabled {
                        SettingsSection(title: "Message Processing", icon: "gearshape.fill") {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Auto-Respond (iMessage only)", isOn: $settings.autoRespondEnabled)
                                    .help("Automatically send iMessage responses based on processing results")

                                if settings.autoRespondEnabled {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("Requires AppleScript setup")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, 24)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("External Program Path:")
                                        .font(.system(size: 13, weight: .medium))

                                    HStack {
                                        TextField("Path to processing program", text: $settings.externalProgramPath)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 12, design: .monospaced))

                                        Button("Browse...") {
                                            selectExternalProgram()
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    Text("Program should accept --file <path> argument")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Processing Directory:")
                                        .font(.system(size: 13, weight: .medium))

                                    HStack {
                                        TextField("Directory path", text: $settings.processingDirectoryPath)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 12, design: .monospaced))

                                        Button("Browse...") {
                                            selectProcessingDirectory()
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }

                                Toggle("Save Message History", isOn: $settings.saveMessageHistory)
                            }
                        }
                    }

                    // MARK: - Privacy & Security
                    SettingsSection(title: "Privacy & Security", icon: "lock.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            PrivacyInfoRow(
                                title: "Local Processing Only",
                                description: "All data stays on your Mac",
                                icon: "checkmark.shield.fill",
                                color: .green
                            )

                            PrivacyInfoRow(
                                title: "No Network Requests",
                                description: "Zero telemetry or analytics",
                                icon: "wifi.slash",
                                color: .blue
                            )

                            Divider()

                            Button(action: {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                            }) {
                                Label("Open System Privacy Settings", systemImage: "gear")
                            }
                            .buttonStyle(.link)
                        }
                    }

                    // MARK: - Warnings
                    if !warnings.isEmpty {
                        SettingsSection(title: "Warnings", icon: "exclamationmark.triangle.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(warnings, id: \.self) { warning in
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.orange)
                                        Text(warning)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Reset
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            validateSettings()
        }
        .onChange(of: settings.screenCaptureEnabled) { _ in
            validateSettings()
        }
        .onChange(of: settings.messageMonitoringEnabled) { _ in
            validateSettings()
        }
        .onChange(of: settings.autoRespondEnabled) { _ in
            validateSettings()
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
                validateSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }

    private func validateSettings() {
        warnings = settings.validateSettings()
    }

    private func selectExternalProgram() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            settings.externalProgramPath = url.path
        }
    }

    private func selectProcessingDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            settings.processingDirectoryPath = url.path
        }
    }
}

// MARK: - Supporting Views

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .background(Color.black.opacity(0.03))
            .cornerRadius(8)
        }
    }
}

struct FeatureToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    let requiresPermission: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isOn ? color : .gray)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }

            if let permission = requiresPermission, isOn {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text("Requires: \(permission) permission")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 32)
            }
        }
    }
}

struct PrivacyInfoRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}
