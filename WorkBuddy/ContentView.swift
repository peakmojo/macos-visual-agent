import SwiftUI

struct ContentView: View {
    @StateObject private var screenMonitor = ScreenMonitor()
    @StateObject private var databaseManager = DatabaseManager()
    @State private var isExpanded = false
    @State private var hoveredBuddy: String? = nil
    @State private var showChat = false
    @State private var buddies = [
        Buddy(id: "alex", name: "Alex", status: .watching, avatar: "A", profileImage: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&h=80&fit=crop&crop=face"),
        Buddy(id: "sarah", name: "Sarah", status: .watching, avatar: "S", profileImage: nil),
        Buddy(id: "mike", name: "Mike", status: .onBreak, avatar: "M", profileImage: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=80&h=80&fit=crop&crop=face")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedView
            } else {
                collapsedView
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
        .animation(.easeInOut(duration: 0.15), value: hoveredBuddy)
        .onAppear {
            // Hardcoded - no database
        }
    }
    
    
    var collapsedView: some View {
        HStack(spacing: 8) {
            // Eye icon with watching count
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 12))
                let watchingCount = buddies.filter { $0.status == .watching }.count
                Text("\(watchingCount) watching")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 12, weight: .medium))
            }
            
            Spacer()
            
            // User avatars
            HStack(spacing: -8) {
                ForEach(buddies.filter { $0.status == .watching }.prefix(2), id: \.id) { buddy in
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                        
                        if let profileImage = buddy.profileImage, let url = URL(string: profileImage) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            } placeholder: {
                                Text(buddy.avatar)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text(buddy.avatar)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .overlay(
                        Circle()
                            .fill(buddy.status == .watching ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                            .offset(x: 8, y: 8)
                    )
                }
            }
            
            Spacer()
            
            // Timer (using screen monitor time or session time)
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 12))
                Text(formatSessionTime())
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Action icons
            HStack(spacing: 8) {
                Button(action: { showChat.toggle() }) {
                    Image(systemName: "message.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 10))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
        )
        .frame(height: 44)
    }
    
    var expandedView: some View {
        VStack(spacing: 0) {
            // Header with title and productivity badge
            HStack {
                Text("Work Buddies")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Productivity badge
                HStack(spacing: 4) {
                    Text("Productivity:")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.8))
                    Text("low")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.2))
                )
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
            
            // Buddies list using new design
            VStack(spacing: 8) {
                ForEach(buddies) { buddy in
                    ModernBuddyRow(
                        buddy: buddy,
                        isHovered: hoveredBuddy == buddy.id,
                        onHover: { isHovered in
                            hoveredBuddy = isHovered ? buddy.id : nil
                        },
                        onToggleStatus: {
                            toggleBuddyStatus(buddy.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            
            // Stats section
            VStack(spacing: 12) {
                Divider()
                    .background(.white.opacity(0.2))
                    .padding(.horizontal, 20)
                
                HStack(spacing: 0) {
                    // Session time
                    VStack(spacing: 4) {
                        Text("Session")
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                        Text(formatSessionTime())
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    // App time
                    VStack(spacing: 4) {
                        Text("App Time")
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                        Text(formatSessionTime())
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    // Focus indicator
                    VStack(spacing: 4) {
                        Text("Focus")
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            
            // Bottom navigation
            HStack(spacing: 0) {
                // Chat button
                Button(action: { showChat.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 14))
                        Text("Chat")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(.white.opacity(0.2))
                    .frame(height: 20)
                
                // Session button
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                        Text("Session")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(.white.opacity(0.2))
                    .frame(height: 20)
                
                // Settings button
                Button(action: {}) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(
                Rectangle()
                    .fill(.white.opacity(0.1))
            )
        }
    }
    
    private func toggleBuddyStatus(_ buddyId: String) {
        if let index = buddies.firstIndex(where: { $0.id == buddyId }) {
            buddies[index].status = buddies[index].status == .watching ? .disabled : .watching
        }
    }
    
    private func formatSessionTime() -> String {
        // For now, return a simple format. This could be connected to actual session tracking later
        let minutes = 29 // Mock 29 minutes to match design
        return "\(minutes)m"
    }
}

struct ModernBuddyRow: View {
    let buddy: Buddy
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onToggleStatus: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with status indicator
            ZStack(alignment: .bottomTrailing) {
                if let profileImage = buddy.profileImage, let url = URL(string: profileImage) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(buddy.avatar)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(buddy.avatar)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }
                
                // Status indicator dot
                Circle()
                    .fill(getStatusColor(buddy))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
                    .offset(x: 2, y: 2)
            }
            
            // Name and status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(buddy.name)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                    Text(getEmojiForBuddy(buddy))
                        .font(.system(size: 15))
                }
                
                Text(getStatusText(buddy))
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.85))
            }
            
            Spacer()
            
            // Status icon
            Button(action: onToggleStatus) {
                Image(systemName: getStatusIcon(buddy))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? .white.opacity(0.1) : .clear)
        )
        .onHover { hovering in
            onHover(hovering)
        }
    }
    
    private func getEmojiForBuddy(_ buddy: Buddy) -> String {
        switch buddy.name {
        case "Alex": return "⭐"
        case "Sarah": return "💋"
        case "Mike": return "😃"
        default: return "👤"
        }
    }
    
    private func getStatusText(_ buddy: Buddy) -> String {
        switch buddy.name {
        case "Alex": return "Analyzing your work"
        case "Sarah": return "Providing assistance" 
        case "Mike": return "Taking a break"
        default: return "Watching your screen"
        }
    }
    
    private func getStatusIcon(_ buddy: Buddy) -> String {
        switch buddy.status {
        case .watching: return "eye.fill"
        case .onBreak: return "phone.down.fill"
        case .disabled: return "phone.down.fill"
        }
    }
    
    private func getStatusColor(_ buddy: Buddy) -> Color {
        switch buddy.status {
        case .watching: return .green
        case .onBreak: return .orange
        case .disabled: return .gray
        }
    }
}

struct StatusBarView: View {
    @State private var sessionTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 8) {
            // Eye icon with watching count
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 12))
                Text("3 watching")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 12, weight: .medium))
            }
            
            Spacer()
            
            // User avatars
            HStack(spacing: -8) {
                // First user avatar (S)
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                    Text("S")
                        .foregroundColor(.white)
                        .font(.system(size: 10, weight: .bold))
                }
                
                // Second user avatar
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.7))
                        .frame(width: 24, height: 24)
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 10))
                }
                .overlay(
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: 8)
                )
            }
            
            Spacer()
            
            // Timer
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 12))
                Text(formatTime(sessionTime))
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Action icons
            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "message.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
        )
        .frame(height: 32)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            sessionTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

struct Buddy: Identifiable {
    let id: String
    let name: String
    var status: BuddyStatus
    let avatar: String
    let profileImage: String?
}

enum BuddyStatus {
    case watching
    case onBreak
    case disabled
    
    var color: Color {
        switch self {
        case .watching: return Color(red: 0.4, green: 0.8, blue: 0.4) // green-400
        case .onBreak: return Color(red: 1.0, green: 0.7, blue: 0.4) // yellow-400
        case .disabled: return Color(red: 0.6, green: 0.6, blue: 0.6) // gray-400
        }
    }
    
    var displayText: String {
        switch self {
        case .watching: return "Watching your screen"
        case .onBreak: return "Taking a break"
        case .disabled: return "Taking a break"
        }
    }
}

