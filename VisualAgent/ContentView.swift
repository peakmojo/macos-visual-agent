import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var screenMonitor = ScreenMonitor()
    @StateObject private var databaseManager = DatabaseManager()
    @State private var isExpanded = false
    @State private var hoveredBuddy: String? = nil
    @State private var showChat = false
    @State private var selectedChatBuddy: Buddy? = nil
    @State private var showQuitConfirmation = false
    @State private var showTaskTimeline = false
    @State private var activityFeed: [ActivityItem] = []
    @State private var showTrialReport = false
    @State private var showActionWindow = false
    @State private var currentWorkflowStep: WorkflowStep = .taskAssignment
    @State private var workflowTimer: Timer?
    @State private var buddies = [
        Buddy(id: "bary", name: "Bary", status: .disabled, avatar: "B", profileImage: "https://readymojo-uploads.s3.us-east-2.amazonaws.com/public-data/ai-interviewers/default/bary_headshot.jpeg", emoji: "⭐", behaviorDescription: "Analyzing your code structure", callState: .idle),
        Buddy(id: "tian", name: "Tian", status: .disabled, avatar: "T", profileImage: "https://readymojo-uploads.s3.us-east-2.amazonaws.com/public-data/ai-interviewers/default/tian_headshot.jpeg", emoji: "💋", behaviorDescription: "Providing async feedback", callState: .idle)
    ]
    
    var body: some View {
        Group {
            if showTaskTimeline {
                // When Task Timeline is open: side-by-side layout
                HStack(spacing: 0) {
                    taskTimelineArea
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    
                    // Right area for Work Buddies components
                    if isExpanded {
                        // Expanded panel on the right
                        HStack {
                            Spacer()
                            VStack {
                                workBuddiesPanel
                                Spacer()
                            }
                        }
                    } else {
                        // Collapsed bar in the right area with optional Action Window below
                        VStack {
                            Spacer()
                                .frame(height: 20)
                            HStack {
                                Spacer()
                                VStack(spacing: 0) {
                                    miniOverlayBar

                                    // Action Window attached panel (curtain drop)
                                    if showActionWindow {
                                        ActionWindowView()
                                            .frame(width: 420, height: 480)
                                            .background(
                                                VStack(spacing: 0) {
                                                    // Seamless connection to main bar
                                                    Rectangle()
                                                        .fill(Color.white.opacity(0.7))
                                                        .frame(height: 12)

                                                    // Main panel background
                                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                        .fill(Color.white.opacity(0.7))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                                        )
                                                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
                                                }
                                            )
                                            .clipShape(
                                                UnevenRoundedRectangle(
                                                    topLeadingRadius: 0,
                                                    bottomLeadingRadius: 24,
                                                    bottomTrailingRadius: 24,
                                                    topTrailingRadius: 0,
                                                    style: .continuous
                                                )
                                            )
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                            .zIndex(10)
                                    }
                                }
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
            } else {
                // When Task Timeline is closed: overlay layout
                GeometryReader { geometry in
                    if isExpanded {
                        // Expanded panel positioned on the right
                        HStack {
                            Spacer()
                            VStack {
                                workBuddiesPanel
                                Spacer()
                            }
                        }
                    } else {
                        // Collapsed bar positioned at top center with optional Action Window below
                        VStack {
                            HStack {
                                Spacer()
                                VStack(spacing: 0) {
                                    miniOverlayBar

                                    // Action Window attached panel (curtain drop)
                                    if showActionWindow {
                                        ActionWindowView()
                                            .frame(width: 420, height: 480)
                                            .background(
                                                VStack(spacing: 0) {
                                                    // Seamless connection to main bar
                                                    Rectangle()
                                                        .fill(Color.white.opacity(0.7))
                                                        .frame(height: 12)

                                                    // Main panel background
                                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                        .fill(Color.white.opacity(0.7))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                                        )
                                                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
                                                }
                                            )
                                            .clipShape(
                                                UnevenRoundedRectangle(
                                                    topLeadingRadius: 0,
                                                    bottomLeadingRadius: 24,
                                                    bottomTrailingRadius: 24,
                                                    topTrailingRadius: 0,
                                                    style: .continuous
                                                )
                                            )
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                            .zIndex(10)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.top, 16)
                            Spacer()
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
        .animation(.easeInOut(duration: 0.25), value: showTaskTimeline)
        .animation(.easeInOut(duration: 0.15), value: hoveredBuddy)
        // Temporarily disabled to debug disappearing window issue
        // .onChange(of: isExpanded) { _ in
        //     updateAppWindowSize()
        // }
        // .onChange(of: showTaskTimeline) { _ in
        //     updateAppWindowSize()
        // }
        .alert("Quit Visual Agent", isPresented: $showQuitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text("Are you sure you want to quit Visual Agent?")
        }
        .onAppear {
            // Hardcoded - no database
            loadSampleActivityFeed()
            startJobSimulationWorkflow()
        }
        .overlay(
            // Founder Chat Module overlay
            Group {
                if showChat, let selectedBuddy = selectedChatBuddy {
                    FounderChatView(
                        buddy: selectedBuddy,
                        isPresented: $showChat
                    )
                }
            }
        )
        .overlay(
            // Trial Report overlay
            Group {
                if showTrialReport {
                    TrialReportView(isPresented: $showTrialReport)
                }
            }
        )
    }
    
    
    // Top Mini Overlay Bar - 320px width, 48px height, floating top-right
    var miniOverlayBar: some View {
        HStack(spacing: 12) {
            // Left: 👁 watching count
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .foregroundColor(.black.opacity(0.7))
                    .font(.system(size: 12))
                let watchingCount = buddies.filter { $0.status == .watching }.count
                Text("\(watchingCount) watching")
                    .foregroundColor(.black.opacity(0.7))
                    .font(.system(size: 12, weight: .medium))
            }
            
            // Center: Founder avatar stacking (Alex, Sarah) + status dots
            HStack(spacing: -6) {
                ForEach(buddies.filter { $0.status == .watching }.prefix(2), id: \.id) { buddy in
                    ZStack {
                        if let profileImage = buddy.profileImage {
                            if profileImage.hasPrefix("http") {
                                AsyncImage(url: URL(string: profileImage)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 28, height: 28)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.white.opacity(0.8))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Text(buddy.avatar)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.black.opacity(0.8))
                                        )
                                }
                            } else {
                                Image(profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                            }
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(buddy.avatar)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black.opacity(0.8))
                                )
                        }
                    }
                    .overlay(
                        Circle()
                            .fill(buddy.status.color)
                            .frame(width: 8, height: 8)
                            .offset(x: 10, y: 10)
                    )
                    .onTapGesture {
                        isExpanded.toggle()
                    }
                }
            }
            
            // Right: ⏱ 29m + tasks button + expand button
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.black.opacity(0.7))
                        .font(.system(size: 12))
                    Text(formatSessionTime())
                        .foregroundColor(.black.opacity(0.7))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showTaskTimeline.toggle()
                    }
                }) {
                    Image(systemName: showTaskTimeline ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                        .foregroundColor(showTaskTimeline ? .blue : .black.opacity(0.7))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Toggle Task Timeline")

                Button(action: { showActionWindow.toggle() }) {
                    Image(systemName: showActionWindow ? "eye.fill" : "eye")
                        .foregroundColor(showActionWindow ? .green : .black.opacity(0.7))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Toggle Action Window")

                Button(action: { showQuitConfirmation = true }) {
                    Image(systemName: "power")
                        .foregroundColor(.black.opacity(0.7))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Quit Visual Agent")

            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .frame(width: 420, height: 48)
    }
    
    // Work Buddies Panel - 400px width, half screen height, right-side slide out
    var workBuddiesPanel: some View {
        VStack(spacing: 0) {
            // Header with title and productivity status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Work Buddies")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.8))
                    HStack(spacing: 6) {
                        Text("Job Simulation")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black.opacity(0.5))
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.black.opacity(0.3))
                        Text(currentWorkflowStep.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Productivity status badge
                HStack(spacing: 4) {
                    Text("Productivity:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.black.opacity(0.6))
                    Text("Moderate")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.9))
                        .overlay(
                            Capsule()
                                .stroke(.black.opacity(0.1), lineWidth: 1)
                        )
                )
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Buddies list using new design
            VStack(spacing: 4) {
                ForEach(buddies) { buddy in
                    ModernBuddyRow(
                        buddy: buddy,
                        isHovered: hoveredBuddy == buddy.id,
                        onHover: { isHovered in
                            hoveredBuddy = isHovered ? buddy.id : nil
                        },
                        onToggleStatus: {
                            handleBuddyCall(buddy.id)
                        },
                        onTap: {
                            selectedChatBuddy = buddy
                            showChat = true
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 12)
            
            // Stats section
            VStack(spacing: 8) {
                Divider()
                    .background(.black.opacity(0.2))
                    .padding(.horizontal, 20)
                
                HStack(spacing: 0) {
                    // Session time
                    VStack(spacing: 4) {
                        Text("Session")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                        Text("1098m")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    // App time
                    VStack(spacing: 4) {
                        Text("App Time")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                        Text("1098m")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    // Focus indicator
                    VStack(spacing: 4) {
                        Text("Focus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            
            // Bottom navigation
            HStack(spacing: 0) {
                // Chat button
                Button(action: { showChat.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 12))
                        Text("Chat")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.black.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(.black.opacity(0.2))
                    .frame(height: 20)
                
                // Report button
                Button(action: { showTrialReport = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 12))
                        Text("Report")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.black.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(.black.opacity(0.2))
                    .frame(height: 20)
                
                // Session button
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                        Text("Session")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.black.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(.black.opacity(0.2))
                    .frame(height: 20)
                
                // Quit button
                Button(action: {
                    showQuitConfirmation = true
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(
                Rectangle()
                    .fill(.black.opacity(0.05))
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 20, x: -5, y: 5)
        )
        .frame(width: 400)
        .frame(maxHeight: NSScreen.main?.frame.height ?? 800)
        .frame(minHeight: 500)
    }
    
    // Task Timeline Area - left-side, collapsible
    var taskTimelineArea: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Task Timeline")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.8))
                    Text("Active Tasks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black.opacity(0.5))
                }
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showTaskTimeline.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Task cards
            ScrollView {
                VStack(spacing: 16) {
                    // Tasks section
                    VStack(spacing: 12) {
                        ForEach(sampleTasks) { task in
                            TaskCard(task: task)
                        }
                    }
                    
                    // Desktop Feed section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "desktopcomputer")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black.opacity(0.6))
                                Text("Desktop Activity")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.black.opacity(0.8))
                            }
                            Spacer()
                            Text("Live")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(.green)
                                )
                        }
                        
                        DesktopFeedView(activityFeed: activityFeed)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
            
            Spacer()
        }
        .frame(width: 380)
        .background(
            Rectangle()
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 15, x: 3, y: 0)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 0)
        )
    }
    
    // Sample tasks data - 5-day UX Designer timeline (Today is Day 4)
    var sampleTasks: [WorkTask] {
        [
            // Day 1 - Onboarding (Completed)
            WorkTask(
                id: "day1-1",
                title: "Day 1: Setup & Company Walkthrough", 
                deadline: "Completed",
                goal: "Get familiar with design system, brand guidelines, and team workflow",
                founderChallenge: "What's your first impression of our design approach?",
                deliverables: ["Slack intro", "Design system review", "Team meet & greet"],
                status: .completed
            ),
            
            // Day 2 - Learning (Completed)
            WorkTask(
                id: "day2-1",
                title: "Day 2: Analyze Current User Flows",
                deadline: "Completed", 
                goal: "Audit existing signup and onboarding experiences across web/mobile",
                founderChallenge: "What are the top 3 friction points you identified?",
                deliverables: ["User flow audit doc", "Heuristic evaluation", "Quick wins list"],
                status: .completed
            ),
            
            // Day 3 - First Real Task (Completed)
            WorkTask(
                id: "day3-1",
                title: "Day 3: Redesign Mobile Onboarding",
                deadline: "Completed",
                goal: "Create improved 3-step mobile onboarding flow with 40% better conversion",
                founderChallenge: "Walk me through your design decisions. Why these specific steps?",
                deliverables: ["Figma mockups", "Prototype link", "Design rationale doc"],
                status: .completed
            ),
            
            // Day 4 - Today (Active)
            WorkTask(
                id: "day4-1",
                title: "Day 4: Dashboard UX Overhaul",
                deadline: "6 hours",
                goal: "Redesign main dashboard to reduce cognitive load and improve task completion by 25%",
                founderChallenge: "How will you validate these UX improvements? Show me your testing plan.",
                deliverables: ["High-fidelity designs", "Interactive prototype", "User testing plan"],
                status: .active
            ),
            
            // Day 5 - Tomorrow (Challenging)
            WorkTask(
                id: "day5-1",
                title: "Day 5: Cross-Platform Design System",
                deadline: "8 hours",
                goal: "Establish scalable design system patterns that work across web, mobile, and tablet",
                founderChallenge: "Convince me why your component architecture will scale as we grow from 10k to 1M users.",
                deliverables: ["Component library", "Design tokens", "Implementation guide", "Scalability presentation"],
                status: .pending
            )
        ]
    }
    
    private func handleBuddyCall(_ buddyId: String) {
        guard let index = buddies.firstIndex(where: { $0.id == buddyId }) else { return }
        
        switch buddies[index].callState {
        case .idle:
            // Start call - show connected state
            buddies[index].callState = .connected
            buddies[index].status = .onBreak
            
            // After 2 seconds, transition to watching
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if buddies.indices.contains(index) && buddies[index].callState == .connected {
                    buddies[index].callState = .watching
                    buddies[index].status = .watching
                }
            }
            
        case .connected:
            // Skip to watching immediately if user clicks while connecting
            buddies[index].callState = .watching
            buddies[index].status = .watching
            
        case .watching:
            // Hang up - return to idle state but keep in list
            buddies[index].callState = .idle
            buddies[index].status = .disabled
        }
    }
    
    private func formatSessionTime() -> String {
        // For now, return a simple format. This could be connected to actual session tracking later
        let minutes = 29 // Mock 29 minutes to match design
        return "\(minutes)m"
    }
    
    private func loadSampleActivityFeed() {
        activityFeed = [
            ActivityItem(
                id: "1",
                appName: "VSCode",
                action: "Edited App.jsx",
                timestamp: Date().addingTimeInterval(-120),
                icon: "curlybraces",
                color: .blue
            ),
            ActivityItem(
                id: "2", 
                appName: "Figma",
                action: "Opened flow_signup.fig",
                timestamp: Date().addingTimeInterval(-300),
                icon: "pencil.and.outline",
                color: .purple
            ),
            ActivityItem(
                id: "3",
                appName: "Cursor",
                action: "GPT prompt: 'How to debounce react input?'",
                timestamp: Date().addingTimeInterval(-420),
                icon: "brain.head.profile",
                color: .orange
            ),
            ActivityItem(
                id: "4",
                appName: "Chrome",
                action: "Browsed 'stripe pricing flow best practices'",
                timestamp: Date().addingTimeInterval(-600),
                icon: "globe",
                color: .green
            ),
            ActivityItem(
                id: "5",
                appName: "Terminal",
                action: "Ran npm install react-debounce",
                timestamp: Date().addingTimeInterval(-720),
                icon: "terminal",
                color: .black
            )
        ]
        
        // Simulate real-time updates
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            addRandomActivity()
        }
    }
    
    private func addRandomActivity() {
        let activities = [
            ("VSCode", "Saved component file", "curlybraces", Color.blue),
            ("Chrome", "Searched React docs", "globe", Color.green),
            ("Terminal", "Git commit", "terminal", Color.black),
            ("Figma", "Updated wireframe", "pencil.and.outline", Color.purple),
            ("Slack", "Received message", "message", Color.indigo)
        ]
        
        let randomActivity = activities.randomElement()!
        let newActivity = ActivityItem(
            id: UUID().uuidString,
            appName: randomActivity.0,
            action: randomActivity.1,
            timestamp: Date(),
            icon: randomActivity.2,
            color: randomActivity.3
        )
        
        activityFeed.insert(newActivity, at: 0)
        if activityFeed.count > 10 {
            activityFeed.removeLast()
        }
    }
    
    private func startJobSimulationWorkflow() {
        // Start the job simulation workflow
        workflowTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            advanceWorkflowStep()
        }
    }
    
    private func advanceWorkflowStep() {
        switch currentWorkflowStep {
        case .taskAssignment:
            // Simulate founder assigning a task
            triggerFounderChallenge()
            currentWorkflowStep = .observation
            
        case .observation:
            // Founders are observing and may inject challenges
            if Bool.random() {
                injectFounderChallenge()
            }
            currentWorkflowStep = .feedback
            
        case .feedback:
            // Provide async feedback
            providAsyncFeedback()
            currentWorkflowStep = .evaluation
            
        case .evaluation:
            // Log performance and create snapshots
            logPerformanceSnapshot()
            currentWorkflowStep = .taskAssignment
        }
    }
    
    private func triggerFounderChallenge() {
        // Simulate a founder challenge being injected
        let challenges = [
            "Can you explain your approach to this problem?",
            "How would you handle edge cases here?",
            "Show me how you would test this component",
            "What performance considerations are you thinking about?"
        ]
        
        // Simulate challenge appearing in chat
        if let randomFounder = buddies.randomElement() {
            // This would trigger a chat notification or message
            print("🧠 \(randomFounder.name) asks: \(challenges.randomElement() ?? "")")
        }
    }
    
    private func injectFounderChallenge() {
        // Inject a mid-task challenge or question
        let contextualChallenges = [
            "I notice you're taking a different approach than expected. Can you walk me through your reasoning?",
            "Quick question - how are you handling error states in this flow?",
            "Interesting solution! Have you considered the accessibility implications?",
            "Before you continue, can you show me the test cases you're planning?"
        ]
        
        if let randomFounder = buddies.filter({ $0.status == .watching }).randomElement() {
            print("💬 \(randomFounder.name) interjects: \(contextualChallenges.randomElement() ?? "")")
        }
    }
    
    private func providAsyncFeedback() {
        // Provide background feedback on current work
        let feedbackMessages = [
            "Good progress on the component structure!",
            "I like how you're handling the state management",
            "Consider extracting that logic into a custom hook",
            "Nice attention to detail on the styling"
        ]
        
        if let randomFounder = buddies.filter({ $0.status == .watching }).randomElement() {
            print("✅ \(randomFounder.name) notes: \(feedbackMessages.randomElement() ?? "")")
        }
    }
    
    private func logPerformanceSnapshot() {
        // Create a performance snapshot for the trial report
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            taskProgress: Double.random(in: 0.6...1.0),
            focusScore: Double.random(in: 0.7...1.0),
            codeQuality: Double.random(in: 0.8...1.0),
            communicationScore: Double.random(in: 0.7...0.9)
        )
        
        print("📊 Performance snapshot logged: \(Int(snapshot.overallScore * 100))%")
    }
    
    private func updateAppWindowSize() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateWindowSize(isExpanded: isExpanded, showTaskTimeline: showTaskTimeline)
        }
    }
}

struct ModernBuddyRow: View {
    let buddy: Buddy
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onToggleStatus: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with status indicator
            ZStack(alignment: .bottomTrailing) {
                if let profileImage = buddy.profileImage {
                    if profileImage.hasPrefix("http") {
                        AsyncImage(url: URL(string: profileImage)) { image in
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
                        Image(profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
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
                    .fill(buddy.status.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
                    .offset(x: 2, y: 2)
            }
            
            // Name and status
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(buddy.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.8))
                    Text(buddy.emoji)
                        .font(.system(size: 14))
                }
                
                Text(buddy.behaviorDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
            }
            
            Spacer()
            
            // Phone call button
            Button(action: onToggleStatus) {
                Image(systemName: buddy.callState.buttonIcon)
                    .font(.system(size: 14))
                    .foregroundColor(buddy.callState.buttonColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(buddy.callState.buttonColor.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? .black.opacity(0.05) : .clear)
        )
        .onHover { hovering in
            onHover(hovering)
        }
        .onTapGesture {
            onTap()
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
    let emoji: String
    let behaviorDescription: String
    var callState: CallState
}

struct WorkTask: Identifiable {
    let id: String
    let title: String
    let deadline: String
    let goal: String
    let founderChallenge: String
    let deliverables: [String]
    let status: TaskStatus
}

enum TaskStatus {
    case active
    case pending
    case completed
    
    var color: Color {
        switch self {
        case .active: return .blue
        case .pending: return .orange
        case .completed: return .green
        }
    }
    
    var displayText: String {
        switch self {
        case .active: return "ACTIVE"
        case .pending: return "PENDING"
        case .completed: return "COMPLETED"
        }
    }
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

enum CallState {
    case idle
    case connected
    case watching
    
    var buttonIcon: String {
        switch self {
        case .idle: return "phone"
        case .connected: return "phone.connection"
        case .watching: return "phone.down"
        }
    }
    
    var buttonColor: Color {
        switch self {
        case .idle: return .blue
        case .connected: return .green
        case .watching: return .red
        }
    }
}

enum WorkflowStep {
    case taskAssignment
    case observation
    case feedback
    case evaluation
    
    var displayName: String {
        switch self {
        case .taskAssignment: return "Task Assignment"
        case .observation: return "Observing"
        case .feedback: return "Feedback"
        case .evaluation: return "Evaluating"
        }
    }
}

struct PerformanceSnapshot {
    let timestamp: Date
    let taskProgress: Double
    let focusScore: Double
    let codeQuality: Double
    let communicationScore: Double
    
    var overallScore: Double {
        (taskProgress + focusScore + codeQuality + communicationScore) / 4
    }
}

struct ActivityItem: Identifiable {
    let id: String
    let appName: String
    let action: String
    let timestamp: Date
    let icon: String
    let color: Color
}

struct DesktopFeedView: View {
    let activityFeed: [ActivityItem]
    
    var body: some View {
        VStack(spacing: 8) {
            if activityFeed.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 24))
                        .foregroundColor(.black.opacity(0.3))
                    Text("No activity detected")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.5))
                }
                .frame(height: 80)
            } else {
                ForEach(activityFeed.prefix(5)) { activity in
                    ActivityFeedRow(activity: activity)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ActivityFeedRow: View {
    let activity: ActivityItem
    
    var body: some View {
        HStack(spacing: 10) {
            // App icon
            Circle()
                .fill(activity.color.opacity(0.1))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: activity.icon)
                        .font(.system(size: 10))
                        .foregroundColor(activity.color)
                )
            
            // Activity details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("[\(activity.appName)]")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(activity.color)
                    Text(activity.action)
                        .font(.system(size: 11))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                Text(formatTimeAgo(activity.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.black.opacity(0.4))
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval) / 60
        
        if minutes < 1 {
            return "just now"
        } else if minutes == 1 {
            return "1 min ago"
        } else if minutes < 60 {
            return "\(minutes) min ago"
        } else {
            let hours = minutes / 60
            return "\(hours)h ago"
        }
    }
}

struct TaskCard: View {
    let task: WorkTask
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Task header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(task.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black.opacity(0.8))
                        
                        Spacer()
                        
                        // Status badge
                        Text(task.status.displayText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(task.status.color)
                            )
                    }
                    
                    // Deadline
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.black.opacity(0.5))
                        Text("Deadline: \(task.deadline)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.black.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(.black.opacity(0.1))
                        .padding(.horizontal, 16)
                    
                    // Goal
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.system(size: 10))
                                .foregroundColor(.black.opacity(0.6))
                            Text("Goal:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.black.opacity(0.7))
                        }
                        Text(task.goal)
                            .font(.system(size: 11))
                            .foregroundColor(.black.opacity(0.7))
                            .padding(.leading, 16)
                    }
                    .padding(.horizontal, 16)
                    
                    // Founder Challenge
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("Founder Challenge:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        Text(task.founderChallenge)
                            .font(.system(size: 11))
                            .foregroundColor(.black.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.orange.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 16)
                    
                    // Deliverables
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.black.opacity(0.6))
                            Text("Deliverables:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.black.opacity(0.7))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(task.deliverables, id: \.self) { deliverable in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(.black.opacity(0.3))
                                        .frame(width: 4, height: 4)
                                    Text(deliverable)
                                        .font(.system(size: 11))
                                        .foregroundColor(.black.opacity(0.7))
                                }
                            }
                        }
                        .padding(.leading, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(task.status.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct TrialReportView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Report panel
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Trial Report")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.black.opacity(0.9))
                                    Text("Job Simulation Summary")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Button(action: { isPresented = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.black.opacity(0.4))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Overall score
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Overall Performance")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.8))
                                    Text("Ready for offer")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                Spacer()
                                
                                // Score circle
                                ZStack {
                                    Circle()
                                        .stroke(Color.green.opacity(0.2), lineWidth: 8)
                                        .frame(width: 80, height: 80)
                                    Circle()
                                        .trim(from: 0, to: 0.85)
                                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .frame(width: 80, height: 80)
                                        .rotationEffect(.degrees(-90))
                                    Text("85%")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.green.opacity(0.05))
                            )
                        }
                        
                        // Daily overview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Overview")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black.opacity(0.8))
                            
                            HStack(spacing: 16) {
                                MetricCard(title: "Work Duration", value: "6h 24m", icon: "clock.fill", color: .blue)
                                MetricCard(title: "Task Switches", value: "12", icon: "arrow.triangle.swap", color: .orange)
                                MetricCard(title: "Focus Score", value: "92%", icon: "brain.head.profile", color: .purple)
                            }
                        }
                        
                        // Founder feedback section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Founder Feedback")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black.opacity(0.8))
                            
                            VStack(spacing: 12) {
                                FounderFeedbackCard(
                                    founder: buddies[0],
                                    rating: 5,
                                    feedback: "Excellent code structure and clean implementation. Shows strong understanding of React patterns."
                                )
                                FounderFeedbackCard(
                                    founder: buddies[1],
                                    rating: 4,
                                    feedback: "Good problem-solving approach. Could improve on asking clarifying questions earlier."
                                )
                                FounderFeedbackCard(
                                    founder: buddies[2],
                                    rating: 4,
                                    feedback: "Solid technical execution. Communication during challenges was professional."
                                )
                            }
                        }
                        
                        // Task completion section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Task Completion")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black.opacity(0.8))
                            
                            VStack(spacing: 8) {
                                TaskCompletionRow(task: "Redesign Signup Flow", score: 95, status: "Completed")
                                TaskCompletionRow(task: "Code Review Dashboard", score: 88, status: "Completed")
                                TaskCompletionRow(task: "API Integration", score: 78, status: "In Progress")
                            }
                        }
                        
                        // Recommendations
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommendations")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black.opacity(0.8))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                RecommendationRow(text: "Continue with current approach to problem-solving", type: .positive)
                                RecommendationRow(text: "Consider asking more questions during requirements gathering", type: .improvement)
                                RecommendationRow(text: "Excellent debugging and error handling skills", type: .positive)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
            .frame(width: 600, height: 700)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.98))
                    .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            )
        }
    }
    
    // Sample buddies for feedback (using the main buddies array would be better)
    private var buddies: [Buddy] {
        [
            Buddy(id: "alex", name: "Alex", status: .watching, avatar: "A", profileImage: nil, emoji: "⭐", behaviorDescription: "Code Reviewer", callState: .watching),
            Buddy(id: "sarah", name: "Sarah", status: .watching, avatar: "S", profileImage: nil, emoji: "💋", behaviorDescription: "Product Manager", callState: .watching),
            Buddy(id: "mike", name: "Mike", status: .watching, avatar: "M", profileImage: nil, emoji: "😀", behaviorDescription: "Tech Lead", callState: .watching)
        ]
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black.opacity(0.9))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct FounderFeedbackCard: View {
    let founder: Buddy
    let rating: Int
    let feedback: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(founder.avatar)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black.opacity(0.8))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(founder.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black.opacity(0.8))
                        Text(founder.emoji)
                            .font(.system(size: 12))
                    }
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(star <= rating ? .yellow : .black.opacity(0.3))
                        }
                    }
                }
                
                Spacer()
            }
            
            Text(feedback)
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.7))
                .lineLimit(nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.black.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct TaskCompletionRow: View {
    let task: String
    let score: Int
    let status: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(task)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.8))
                Text(status)
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.5))
            }
            
            Spacer()
            
            Text("\(score)%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(score >= 80 ? .green : score >= 60 ? .orange : .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.02))
        )
    }
}

struct RecommendationRow: View {
    let text: String
    let type: RecommendationType
    
    enum RecommendationType {
        case positive
        case improvement
        
        var icon: String {
            switch self {
            case .positive: return "checkmark.circle.fill"
            case .improvement: return "lightbulb.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .positive: return .green
            case .improvement: return .orange
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 12))
                .foregroundColor(type.color)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.7))
                .lineLimit(nil)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(type.color.opacity(0.1))
        )
    }
}

struct FounderChatView: View {
    let buddy: Buddy
    @Binding var isPresented: Bool
    @State private var messageText = ""
    @State private var selectedTab = "Today"
    @State private var messages: [ChatMessage] = []
    
    let tabs = ["Today", "Timeline", "Feedback"]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 0) {
                    // Chat header
                    HStack {
                        // Buddy avatar and info
                        HStack(spacing: 10) {
                            if let profileImage = buddy.profileImage {
                                if profileImage.hasPrefix("http") {
                                    AsyncImage(url: URL(string: profileImage)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.white.opacity(0.8))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Text(buddy.avatar)
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.black.opacity(0.8))
                                            )
                                    }
                                } else {
                                    Image(profileImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                }
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(buddy.avatar)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.black.opacity(0.8))
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(buddy.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.8))
                                    Text(buddy.emoji)
                                        .font(.system(size: 12))
                                }
                                Text("Founder")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.black.opacity(0.4))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.95))
                    
                    // Chat tabs
                    HStack(spacing: 0) {
                        ForEach(tabs, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
                                Text(tab)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(selectedTab == tab ? .black.opacity(0.8) : .black.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Rectangle()
                                            .fill(selectedTab == tab ? Color.white : Color.clear)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .background(Color.black.opacity(0.05))
                    
                    // Message area
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if messages.isEmpty {
                                VStack(spacing: 8) {
                                    Text("Start a conversation with \(buddy.name)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black.opacity(0.6))
                                    Text(buddy.behaviorDescription)
                                        .font(.system(size: 12))
                                        .foregroundColor(.black.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else {
                                ForEach(messages) { message in
                                    ChatBubble(message: message, buddy: buddy)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .frame(height: 200)
                    .background(Color.white.opacity(0.98))
                    
                    // Input area
                    HStack(spacing: 10) {
                        TextField("Type a message...", text: $messageText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black.opacity(0.05))
                            )
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Circle().fill(Color.blue))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button(action: {}) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.black.opacity(0.6))
                                .padding(8)
                                .background(Circle().fill(Color.black.opacity(0.1)))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.95))
                }
                .frame(width: 350)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.98))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            loadInitialMessages()
        }
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let newMessage = ChatMessage(
            id: UUID().uuidString,
            text: trimmedText,
            isFromUser: true,
            timestamp: Date()
        )
        
        messages.append(newMessage)
        messageText = ""
        
        // Simulate founder response after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let responses = [
                "I see you're working on that. Good progress!",
                "Interesting approach. Have you considered alternative methods?",
                "That's exactly what I would expect from a strong candidate.",
                "Keep going, you're on the right track."
            ]
            
            let response = ChatMessage(
                id: UUID().uuidString,
                text: responses.randomElement() ?? "Thanks for the update!",
                isFromUser: false,
                timestamp: Date()
            )
            messages.append(response)
        }
    }
    
    private func loadInitialMessages() {
        let initialMessages = [
            ChatMessage(
                id: "1",
                text: "Hey there! I'm \(buddy.name). \(buddy.behaviorDescription.lowercased()). Feel free to ask me anything!",
                isFromUser: false,
                timestamp: Date().addingTimeInterval(-300)
            )
        ]
        messages = initialMessages
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}

struct ChatBubble: View {
    let message: ChatMessage
    let buddy: Buddy
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue)
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.black.opacity(0.4))
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(buddy.avatar)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black.opacity(0.6))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.text)
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.08))
                            )
                        
                        Text(formatTime(message.timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.black.opacity(0.4))
                    }
                }
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    private let material: NSVisualEffectView.Material
    private let blendingMode: NSVisualEffectView.BlendingMode
    private let isEmphasized: Bool
    
    init(material: NSVisualEffectView.Material = .hudWindow, 
         blendingMode: NSVisualEffectView.BlendingMode = .behindWindow, 
         emphasized: Bool = false) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = emphasized
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.autoresizingMask = [.width, .height]
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = isEmphasized
    }
}

