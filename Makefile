# Makefile for Visual Agent macOS App

# Variables
APP_NAME = VisualAgent
SCHEME = VisualAgent
PROJECT = VisualAgent.xcodeproj
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
APP_PATH = $(ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app
DMG_PATH = $(BUILD_DIR)/$(APP_NAME).dmg
DMG_VOLUME_NAME = "Visual Agent"

# Configuration
CONFIGURATION = Release
DERIVED_DATA_PATH = $(BUILD_DIR)/DerivedData

# Version info (will be extracted from Info.plist)
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" VisualAgent/Info.plist 2>/dev/null || echo "1.0")
BUILD_NUMBER := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" VisualAgent/Info.plist 2>/dev/null || echo "1")

.PHONY: all clean build archive dmg release help install-deps

# Default target
all: dmg

# Help target
help:
	@echo "Visual Agent Build System"
	@echo "========================="
	@echo ""
	@echo "Targets:"
	@echo "  make build       - Build the app"
	@echo "  make archive     - Create an archive"
	@echo "  make dmg         - Create a DMG installer (default)"
	@echo "  make release     - Create a GitHub release with DMG"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make install-deps- Install dependencies (create-dmg)"
	@echo ""
	@echo "Current version: $(VERSION) (build $(BUILD_NUMBER))"

# Install dependencies
install-deps:
	@echo "📦 Installing dependencies..."
	@command -v create-dmg >/dev/null 2>&1 || { \
		echo "Installing create-dmg via Homebrew..."; \
		brew install create-dmg; \
	}
	@echo "✅ Dependencies installed"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf ~/Library/Developer/Xcode/DerivedData/$(APP_NAME)-*
	@echo "✅ Clean complete"

# Build the app
build:
	@echo "🔨 Building $(APP_NAME)..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		build
	@echo "✅ Build complete"

# Create archive
archive: clean
	@echo "📦 Creating archive..."
	mkdir -p $(BUILD_DIR)
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-archivePath $(ARCHIVE_PATH) \
		archive
	@echo "✅ Archive created at $(ARCHIVE_PATH)"

# Create DMG
dmg: archive install-deps
	@echo "💿 Creating DMG installer..."
	@mkdir -p $(BUILD_DIR)/dmg
	@cp -R $(APP_PATH) $(BUILD_DIR)/dmg/
	@echo "Using create-dmg to build DMG..."
	create-dmg \
		--volname $(DMG_VOLUME_NAME) \
		--window-pos 200 120 \
		--window-size 800 400 \
		--icon-size 100 \
		--icon "$(APP_NAME).app" 200 190 \
		--hide-extension "$(APP_NAME).app" \
		--app-drop-link 600 185 \
		--no-internet-enable \
		"$(DMG_PATH)" \
		"$(BUILD_DIR)/dmg/" \
		|| true
	@if [ -f "$(DMG_PATH)" ]; then \
		echo "✅ DMG created successfully at $(DMG_PATH)"; \
		echo "📊 DMG size: $$(du -h $(DMG_PATH) | cut -f1)"; \
	else \
		echo "❌ DMG creation failed"; \
		exit 1; \
	fi

# Create GitHub release and upload DMG
release: dmg
	@echo "🚀 Creating GitHub release..."
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "❌ Error: GITHUB_TOKEN environment variable not set"; \
		echo "Set it with: export GITHUB_TOKEN=your_token_here"; \
		exit 1; \
	fi
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "❌ Error: GitHub CLI (gh) not found"; \
		echo "Install with: brew install gh"; \
		exit 1; \
	fi
	@echo "Creating release v$(VERSION)..."
	@gh release create "v$(VERSION)" \
		--title "Visual Agent v$(VERSION)" \
		--notes "Release notes for version $(VERSION)" \
		--draft \
		$(DMG_PATH)
	@echo "✅ Release created! Edit at: https://github.com/$$(git config --get remote.origin.url | sed 's/.*://;s/.git$$//')/releases"
	@echo "📝 Don't forget to:"
	@echo "   1. Edit release notes"
	@echo "   2. Publish the draft release"

# Quick development build (no archive, just build)
dev:
	@echo "🔨 Quick development build..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		build
	@echo "✅ Development build complete"

# Open the built app
open: build
	@echo "🚀 Opening $(APP_NAME)..."
	@open $(DERIVED_DATA_PATH)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app

# Show build info
info:
	@echo "📋 Build Information"
	@echo "==================="
	@echo "App Name:        $(APP_NAME)"
	@echo "Version:         $(VERSION)"
	@echo "Build Number:    $(BUILD_NUMBER)"
	@echo "Configuration:   $(CONFIGURATION)"
	@echo "Project:         $(PROJECT)"
	@echo "Scheme:          $(SCHEME)"
	@echo "Build Directory: $(BUILD_DIR)"
	@echo ""
	@echo "Xcode Version:"
	@xcodebuild -version
