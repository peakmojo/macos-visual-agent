<div align="center">

# 🎯 Visual Agent

### *Your Mac, but it actually understands what's on screen*

**Screen understanding using Apple's Accessibility APIs—soon powered by local LLMs**

[🚀 Demo](#demo) • [⚡ Quick Start](#quick-start) • [🧠 How It Works](#how-it-works) • [🔐 Privacy](#privacy)

![macOS](https://img.shields.io/badge/macOS-13.0+-000000.svg?style=flat&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-FA7343.svg?style=flat&logo=swift)
![ScreenCaptureKit](https://img.shields.io/badge/ScreenCaptureKit-Native-blue.svg?style=flat)
![Accessibility](https://img.shields.io/badge/Accessibility%20API-Native-purple.svg?style=flat)
![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)

</div>

---

## 🎬 Demo

> *Coming soon: GIF showing the overlay in action, UI tree extraction, and activity timeline*

**What you'll see:**
- Floating minimal overlay that tracks your work in real-time
- Accessibility API extracting UI elements from any app (buttons, text fields, menus)
- Activity timeline showing your workflow patterns
- All running locally at 1 FPS—no cloud, no tracking
- **Soon:** Local LLM understanding full screen context

---

## 💡 Why This Exists

Most productivity tools are either:
- 🚫 **Invasive** (uploading your screen to the cloud)
- 🚫 **Limited** (only track app names, not context)
- 🚫 **Closed-source** (you have no idea what they're doing with your data)

**Visual Agent is different:**
- ✅ 100% local processing using Apple's native Accessibility APIs
- ✅ Works with ANY application—extracts actual UI structure, not just pixels
- ✅ Fully open source—audit every line of code
- ✅ Built by developers, for developers
- ✅ **Coming soon:** Local LLM integration for semantic understanding

### The Problem It Solves

Ever wondered:
- *"How much time did I actually spend focused today?"*
- *"What was I working on 2 hours ago?"*
- *"Which apps are killing my productivity?"*

Traditional time trackers only see app names. **Visual Agent sees structure**—the actual UI elements, window layouts, and soon, semantic meaning via local LLMs.

---

## ⚡ Quick Start

```bash
# Clone and build
git clone https://github.com/yourusername/macos-visual-agent.git
cd macos-visual-agent
open VisualAgent.xcodeproj

# Grant permissions when prompted (Screen Recording + Accessibility)
# Launch from Xcode or build for Release
```

**That's it.** The floating overlay appears in your top-right corner.

---

## 🧠 How It Works

### The Intelligence Pipeline

```
Screen Capture (1 FPS)
    ↓
Accessibility APIs → Extract UI tree (buttons, inputs, text, menus)
    ↓
Vision Framework → Capture visible text with coordinates
    ↓
Window Manager → Track active apps & window layouts
    ↓
[COMING SOON] Local LLM → Semantic understanding of screen context
    ↓
In-Memory Processing → Real-time insights (persistence coming soon)
```

### Under the Hood

This isn't some Electron wrapper running a Chrome browser. It's **pure native Swift** using Apple's most powerful APIs:

| Framework | What It Does |
|-----------|-------------|
| **Accessibility APIs** | Extracts complete UI tree—every button, text field, menu with exact coordinates |
| **ScreenCaptureKit** | Captures display at 1 FPS (macOS 12.3+) for visual context |
| **Vision Framework** | Detects text regions and extracts content with word-level bounding boxes |
| **SwiftUI** | Native, buttery-smooth 120Hz interface |
| **[Coming]** Local LLM | Ollama/MLX integration for semantic screen understanding |
| **[Coming]** Vector DB | Persistent storage with semantic search capabilities |

**Performance:** Uses ~50MB RAM, <2% CPU on Apple Silicon.

---

## 🎨 What Makes This Special

### 1. **Accessibility-First Architecture**
Unlike screen scraping or pixel-based hacks, Visual Agent uses Apple's **Accessibility APIs**—the same system VoiceOver uses:
- Extract complete UI hierarchies from any app
- Get precise element types (button, checkbox, text field, etc.)
- Know exact coordinates and states
- Works even with custom UI frameworks

**Why this matters:** Way more accurate than traditional methods. Works with native apps, Electron apps, web apps—everything.

### 2. **Local LLM Ready**
The architecture is designed for **local AI integration**:
```
Screen Context → UI Tree + Visual Data → Local LLM → Semantic Understanding
```

Imagine:
- "Show me all code-related activity from yesterday"
- "What documentation was I reading when I wrote this function?"
- "Auto-tag my work sessions by project context"

**Privacy-first:** Your screen data never leaves your Mac. Run Ollama or MLX models locally.

### 3. **Ridiculously Extensible**
Want to build:
- A personal search engine of everything you've seen?
- RAG system with your entire work context?
- AI copilot that sees your full development environment?
- Context-aware automation ("when Figma opens, show design system docs")?

**You can.** The architecture is modular—just plug into `ContextStreamManager`.

---

## 🔐 Privacy

### What This App Does NOT Do

- ❌ **No keystroke logging** (removed in security audit)
- ❌ **No network requests** (check the code—zero external API calls)
- ❌ **No cloud uploads** (everything stays on your Mac)
- ❌ **No telemetry or tracking** (not even anonymous analytics)
- ❌ **No persistent storage yet** (currently in-memory only)

### What It DOES Collect (100% Locally, In-Memory)

- ✅ UI element metadata → button labels, text fields, window titles
- ✅ Screen captures → processed for visual context, then discarded
- ✅ Text regions → what's visible and where
- ✅ App usage patterns → which apps you're using when

**Current state:** All data is in-memory and lost when you quit the app.

**Coming soon:** Optional local persistence with vector embeddings for semantic search.

### For the Paranoid (We Love You)

```bash
# Verify zero network activity
sudo lsof -i -P | grep VisualAgent  # Should return nothing

# Audit the code yourself
grep -r "URLSession\|fetch\|http" VisualAgent/  # Zero API calls

# Check for any data files
find ~/Library -name "*visualagent*" -o -name "*VisualAgent*"  # Currently none
```

**When LLM support arrives:** All inference runs locally via Ollama or MLX. Your data never touches the internet.

---

## 🚀 Use Cases

**For Developers:**
- Track context switches: Xcode → docs → StackOverflow → Slack
- See actual productivity patterns beyond "Chrome was open for 4 hours"
- Build AI dev tools that understand your full environment
- Create personal knowledge base from your screen history

**For Researchers:**
- Study UI/UX patterns in real applications
- Log screen interactions for user studies (with consent)
- Analyze accessibility compliance across apps
- Build datasets of human-computer interaction

**For Hackers & Tinkerers:**
- Personal "time machine" search of everything you've seen
- Auto-journal your workday based on actual screen context
- Context-aware automation and workflows
- Train local AI models on your work patterns

---

## 🛠️ Architecture for Contributors

```
VisualAgent/
├── 📸 ScreenCaptureManager.swift      → ScreenCaptureKit wrapper (1 FPS)
├── 🎯 AccessibilityAnalyzer.swift     → UI tree extraction via AX APIs
├── 🧠 VisionTextExtractor.swift       → Text detection with coordinates
├── 🔄 ContextStreamManager.swift      → Pipeline coordinator
├── 🎨 ContentView.swift               → SwiftUI overlay interface
└── [Coming] LLMContextProcessor.swift → Local LLM integration
```

**Current Stack:**
- Accessibility APIs for UI structure
- Vision framework for text + coordinates
- Native screen capture at 1 FPS
- In-memory state management

**Coming Soon:**
- Ollama integration for local LLaMA/Mistral models
- MLX support for Apple Silicon optimized inference
- Vector database for persistent semantic search
- RAG pipeline for screen memory

**Want to contribute?**
- Help integrate Ollama/MLX for local LLM support
- Design the persistence layer (vector DB, embeddings)
- Build export plugins (Obsidian, Notion, CSV)
- Create visualization tools for screen timelines
- Multi-monitor support

No webpack. No npm. No bullshit. Just Swift + Xcode.

---

## 🎯 Roadmap

**Phase 1: Native Foundation** (✅ Done)
- [x] Screen capture at 1 FPS via ScreenCaptureKit
- [x] Accessibility API integration for UI tree extraction
- [x] Vision framework for text detection
- [x] Floating overlay interface
- [x] In-memory activity tracking

**Phase 2: Persistence & Intelligence** (🚧 Next)
- [ ] Local persistence layer (vector DB or similar)
- [ ] Smart activity categorization (coding vs. browsing vs. meetings)
- [ ] Export formats (JSON, CSV, Markdown)
- [ ] Data retention policies (auto-cleanup after N days)
- [ ] Encryption for stored data

**Phase 3: Local AI Superpowers** (💡 Planned)
- [ ] **Ollama integration** → Run LLaMA 3.3, Mistral locally
- [ ] **MLX support** → Apple Silicon optimized inference
- [ ] **Vector embeddings** → Semantic understanding of screen context
- [ ] **RAG pipeline** → "Search everything I've seen this week about React hooks"
- [ ] **Semantic tagging** → Auto-categorize sessions by project/topic
- [ ] **Context-aware insights** → "You're most productive in morning sessions when..."

**Phase 4: Ecosystem** (🔮 Future)
- [ ] Plugin system for custom analyzers
- [ ] Multi-display support
- [ ] Team features (opt-in collaborative insights)
- [ ] API for third-party integrations

---

## 🤝 Contributing

**We want your ideas—especially around local LLM integration.**

Working on Ollama/MLX/llama.cpp? Want to help make this the best local-first productivity tool?

1. **Open an issue** first—let's discuss your idea
2. **Fork & build** your changes
3. **Submit a PR** with clear description

**Priority areas:**
- Local LLM integration (Ollama, MLX)
- Persistence layer design (vector DB, embeddings)
- RAG implementation for screen memory
- Privacy-preserving analytics
- Export & visualization tools

**No bureaucracy. No corporate approval. Just ship.**

---

## 📜 License

MIT License—build products, fork it, sell it, integrate it, we don't care.

Just keep it local. Keep it open. Keep it honest.

---

<div align="center">

### ⭐ If local-first AI tools matter to you, star this.

### 🍴 If you want to build something with screen context, fork it.

### 🚀 If you're working on local LLMs, let's collaborate.

---

**Built with ❤️ by developers who believe your screen data belongs on YOUR machine.**

**Not in some cloud. Not feeding someone's AI training pipeline. Just yours.**

[Report Bug](https://github.com/yourusername/macos-visual-agent/issues) • [Request Feature](https://github.com/yourusername/macos-visual-agent/issues) • [Discussions](https://github.com/yourusername/macos-visual-agent/discussions)

</div>
