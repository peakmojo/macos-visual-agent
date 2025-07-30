import SwiftUI

struct ContentView: View {
    @StateObject private var screenMonitor = ScreenMonitor()
    @StateObject private var databaseManager = DatabaseManager()
    @State private var isExpanded = false
    @State private var hoveredBuddy: String? = nil
    @State private var showChat = false
    @State private var buddies = [
        Buddy(id: "alex", name: "Alex", status: .watching, avatar: "A", profileImage: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face"),
        Buddy(id: "sarah", name: "Sarah", status: .watching, avatar: "S", profileImage: "https://images.unsplash.com/photo-1494790108755-2616b612b77c?w=100&h=100&fit=crop&crop=face"),
        Buddy(id: "mike", name: "Mike", status: .onBreak, avatar: "M", profileImage: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face")
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
        )
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
        .animation(.easeInOut(duration: 0.15), value: hoveredBuddy)
        .onAppear {
            // Load buddies from database or save defaults
            let savedBuddies = databaseManager.loadBuddies()
            if savedBuddies.isEmpty {
                // Save default buddies to database
                for buddy in buddies {
                    databaseManager.saveBuddy(buddy)
                }
            } else {
                buddies = savedBuddies
            }
            
            // Start monitoring if any buddy is watching
            let anyWatching = buddies.contains { $0.status == .watching }
            if anyWatching {
                screenMonitor.startMonitoring()
            }
        }
    }
    
    var collapsedView: some View {
        HStack(spacing: 12) {
            // Eye icon and count
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                let watchingCount = buddies.filter { $0.status == .watching }.count
                Text("\(watchingCount) watching")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // Overlapping avatars
            HStack(spacing: -8) {
                ForEach(buddies.filter { $0.status == .watching }.prefix(3), id: \.id) { buddy in
                    ZStack {
                        Circle()
                            .fill(Color.white)
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
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text(buddy.avatar)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
                    
                    // Status indicator dot
                    .overlay(
                        Circle()
                            .fill(buddy.status == .watching ? Color(red: 0.4, green: 0.8, blue: 0.4) : buddy.status == .onBreak ? Color(red: 1.0, green: 0.7, blue: 0.4) : Color(red: 0.6, green: 0.6, blue: 0.6))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                            )
                            .offset(x: 8, y: 8)
                        , alignment: .bottomTrailing
                    )
                }
            }
            
            // Chat and expand buttons
            HStack(spacing: 4) {
                // New message indicator
                if showChat {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                }
                
                Button(action: { showChat.toggle() }) {
                    Image(systemName: "message")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 48)
    }
    
    var expandedView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Work Buddies")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            
            // Buddies List
            VStack(spacing: 8) {
                ForEach(buddies) { buddy in
                    BuddyRow(
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
            
            // Bottom section with Chat button and Settings
            HStack(spacing: 8) {
                Button(action: { showChat.toggle() }) {
                    HStack {
                        Image(systemName: "message")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Chat")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        if showChat {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                Button(action: {}) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            .overlay(
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 1)
                , alignment: .top
            )
        }
        .padding(16)
    }
    
    private func toggleBuddyStatus(_ buddyId: String) {
        if let index = buddies.firstIndex(where: { $0.id == buddyId }) {
            buddies[index].status = buddies[index].status == .watching ? .disabled : .watching
            
            // Save to database
            databaseManager.saveBuddy(buddies[index])
            
            // Start/stop monitoring based on if any buddy is watching
            let anyWatching = buddies.contains { $0.status == .watching }
            if anyWatching && !screenMonitor.isMonitoring {
                screenMonitor.startMonitoring()
            } else if !anyWatching && screenMonitor.isMonitoring {
                screenMonitor.stopMonitoring()
            }
        }
    }
}

struct BuddyRow: View {
    let buddy: Buddy
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onToggleStatus: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with status indicator
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                    
                    if let profileImage = buddy.profileImage, let url = URL(string: profileImage) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } placeholder: {
                            Text(buddy.avatar)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text(buddy.avatar)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                // Status indicator dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.2), lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(buddy.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(buddy.status.displayText)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Status toggle button (visible on hover)
            if isHovered {
                Button(action: onToggleStatus) {
                    Image(systemName: buddy.status == .watching ? "eye" : "eye.slash")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
        )
        .onHover { hovering in
            onHover(hovering)
        }
    }
    
    private var statusColor: Color {
        switch buddy.status {
        case .watching: return .green
        case .onBreak: return .orange
        case .disabled: return .gray
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

#Preview {
    ContentView()
        .frame(width: 280, height: 400)
}