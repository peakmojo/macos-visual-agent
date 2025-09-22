import SwiftUI
import CoreGraphics

struct ActionWindowView: View {
    @StateObject private var contextManager = ContextStreamManager()
    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Tab Selector
            tabSelector

            // Content Area
            contentArea

            // Footer with controls
            footerSection
        }
        .background(Color.clear)
        .onAppear {
            Task {
                await contextManager.startStreaming()
            }
        }
        .onDisappear {
            contextManager.stopStreaming()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let context = contextManager.currentContext {
                    Text("\(context.captureContext.frontmostAppName ?? "Unknown App")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black.opacity(0.9))
                } else {
                    Text("No active context")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black.opacity(0.4))
                }
            }

            Spacer()

            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(contextManager.isStreaming ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(contextManager.isStreaming ? "Live" : "Offline")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
            }

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.8))
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                Button(action: { selectedTab = index }) {
                    HStack(spacing: 4) {
                        Image(systemName: tabIcon(for: index))
                            .font(.system(size: 12))
                        Text(tabTitle(for: index))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedTab == index ? .blue : .black.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Rectangle()
                            .fill(selectedTab == index ? Color.blue.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.black.opacity(0.05))
    }

    // MARK: - Content Area

    private var contentArea: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                switch selectedTab {
                case 0:
                    screenDescriptionView
                case 1:
                    textStringsView
                case 2:
                    uiElementsView
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 400)
    }

    // MARK: - Screen Description View

    private var screenDescriptionView: some View {
        Group {
            if let context = contextManager.currentContext {
                VStack(alignment: .leading, spacing: 12) {
                    Text(context.screenDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        )
                }
            } else {
                noDataView("No screen capture available")
            }
        }
    }

    // MARK: - Text Strings View

    private var textStringsView: some View {
        Group {
            if let context = contextManager.currentContext, !context.textStrings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(context.textStrings.joined(separator: "\n"))
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.8))
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        )
                }
            } else {
                noDataView("No text detected")
            }
        }
    }

    // MARK: - UI Elements View

    private var uiElementsView: some View {
        Group {
            if let context = contextManager.currentContext, !context.uiElements.isEmpty {
                ForEach(context.uiElements.prefix(15), id: \.id) { uiElement in
                    UIElementCard(uiElement: uiElement)
                }
            } else {
                noDataView("No UI elements detected")
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack {
            // Stats
            let stats = contextManager.processingStats
            HStack(spacing: 12) {
                StatItem(title: "FPS", value: String(format: "%.1f", stats.fps))
                StatItem(title: "Text", value: "\(stats.lastTextElementCount)")
                StatItem(title: "UI", value: "\(stats.lastUIElementCount)")
                StatItem(title: "Updates", value: "\(stats.totalUpdates)")
            }

            Spacer()

            // Last update time
            if let lastUpdate = contextManager.lastUpdateTime {
                Text("Updated \(timeAgo(lastUpdate))")
                    .font(.system(size: 10))
                    .foregroundColor(.black.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.03))
    }

    // MARK: - Helper Views

    private func noDataView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(.black.opacity(0.3))
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helper Functions

    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "tv"
        case 1: return "textformat"
        case 2: return "rectangle.3.offgrid"
        default: return "questionmark"
        }
    }

    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Screen"
        case 1: return "Text"
        case 2: return "UI"
        default: return "Unknown"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else {
            return "\(Int(interval / 60))m ago"
        }
    }
}

// MARK: - Element Cards

struct UIElementCard: View {
    let uiElement: UIElement

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: uiElement.elementType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.blue)

                Text(uiElement.displayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.8))
                    .lineLimit(1)

                Spacer()

                Text(uiElement.elementType.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(.black.opacity(0.6))
            }

            HStack {
                Text("Frame: \(Int(uiElement.frame.width))×\(Int(uiElement.frame.height))")
                    .font(.system(size: 10))
                    .foregroundColor(.black.opacity(0.5))

                Spacer()

                if uiElement.enabled {
                    Text("Enabled")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    Text("Disabled")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(uiElement.enabled ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black.opacity(0.8))
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.black.opacity(0.5))
        }
    }
}