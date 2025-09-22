import SwiftUI
import CoreGraphics
import AppKit

struct ActionWindowView: View {
    @StateObject private var contextManager = ContextStreamManager()
    @State private var showCopyFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Content Area (text only)
            textContentArea

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

            // Status indicators
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(contextManager.isStreaming ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(contextManager.isStreaming ? "Live" : "Offline")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                }

                // CoreML Status with detailed info
                if #available(macOS 12.0, *) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10))
                                .foregroundColor(getCoreMLStatusColor())

                            Text("CoreML")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.black.opacity(0.6))
                        }

                        // CoreML stats
                        let stats = contextManager.coreMLStats
                        Text("\(Int(stats.successRate * 100))% (\(stats.successfulUses)/\(stats.totalAttempts))")
                            .font(.system(size: 8))
                            .foregroundColor(.black.opacity(0.5))

                        if !stats.lastReason.isEmpty && stats.lastReason != "not attempted" {
                            Text(stats.lastReason)
                                .font(.system(size: 8))
                                .foregroundColor(getReasonColor(stats.lastReason))
                        }
                    }
                }
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.8))
    }

    // MARK: - Text Content Area

    private var textContentArea: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                textStringsView
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 400)
    }


    // MARK: - Text Strings View

    private var textStringsView: some View {
        Group {
            if let context = contextManager.currentContext, !context.screenDescription.isEmpty {
                textContentView(for: context)
            } else {
                noDataView("No screen analysis available")
            }
        }
    }

    private func textContentView(for context: ScreenContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(context.screenDescription)
                .font(.system(size: 10).monospaced())
                .foregroundColor(.black.opacity(0.8))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(textBackgroundView)
                .onTapGesture {
                    copyTextToClipboard(context.screenDescription)
                }
                .help("Click to copy all screen analysis to clipboard")
        }
    }

    private var textBackgroundView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(showCopyFeedback ? Color.green.opacity(0.1) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(showCopyFeedback ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
    }


    // MARK: - Footer Section

    private var footerSection: some View {
        HStack {
            // Stats
            let stats = contextManager.processingStats
            HStack(spacing: 12) {
                StatItem(title: "FPS", value: String(format: "%.1f", stats.fps))
                StatItem(title: "Text", value: "\(stats.lastTextElementCount)")
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

    @available(macOS 12.0, *)
    private func getCoreMLStatusColor() -> Color {
        let stats = contextManager.coreMLStats
        if stats.isCurrentlyWorking {
            return .green // Green when CoreML is actively working
        } else if stats.lastReason == "timeout" {
            return .orange // Orange when skipped due to performance
        } else if stats.lastReason == "unavailable" {
            return .red // Red when unavailable
        } else {
            return .blue // Blue when available but not used recently
        }
    }

    private func getReasonColor(_ reason: String) -> Color {
        switch reason {
        case "success": return .green
        case "timeout": return .orange
        case "unavailable": return .red
        default: return .gray
        }
    }

    private func copyTextToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Show visual feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopyFeedback = true
        }

        // Hide feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopyFeedback = false
            }
        }

        print("📋 Copied \(text.count) characters to clipboard")
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