# iMessage & WeChat Monitoring Setup Guide

## Overview

Visual Agent now includes real-time monitoring for iMessage and WeChat notifications. This feature uses macOS Accessibility APIs to capture notifications, extract attachments, process them with external programs, and optionally send responses.

## Architecture

```
Notification Appears (iMessage/WeChat)
    ↓
NotificationCenterObserver (Accessibility API)
    ↓
NotificationParser (Extract sender, message, attachments)
    ↓
MessageAttachmentWatcher (FSEvents monitors for files)
    ↓
MessageProcessor (Orchestrates pipeline)
    ↓
External Program Execution
    ↓
MessageResponder (Send iMessage reply via AppleScript)
```

## Prerequisites

### 1. macOS Accessibility Permissions

**Required for**: Notification monitoring

**How to grant:**

1. Open **System Settings** (or System Preferences on older macOS)
2. Navigate to **Privacy & Security** → **Accessibility**
3. Click the lock icon and authenticate
4. Click the **+** button
5. Navigate to `/Users/your username/git/macos-visual-agent/build/DerivedData/Build/Products/Debug/VisualAgent.app`
6. Click **Open**
7. Ensure the checkbox next to Visual Agent is **enabled**

**Note**: Visual Agent will automatically request this permission when launched. If denied, notification monitoring will not work.

### 2. Full Disk Access (for attachment files)

**Required for**: Accessing attachment files from Messages and WeChat

**How to grant:**

1. Open **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Click the lock and authenticate
3. Click **+**
4. Add **VisualAgent.app**
5. Enable the checkbox

### 3. AppleScript for iMessage Responses (Optional)

**Required for**: Sending automated iMessage responses

**Setup:**

The AppleScript file needs to be placed in the Application Scripts directory:

**Location**: `~/Library/Application Scripts/com.visualagent.VisualAgent/sendMessage.scpt`

**Script content**:

```applescript
on run {targetBuddy, messageText}
    tell application "Messages"
        set targetService to 1st service whose service type = iMessage
        set theBuddy to buddy targetBuddy of targetService
        send messageText to theBuddy
    end tell
end run
```

**To create the script**:

```bash
# Create directory
mkdir -p ~/Library/Application\ Scripts/com.visualagent.VisualAgent/

# Create the script file
cat > ~/Library/Application\ Scripts/com.visualagent.VisualAgent/sendMessage.scpt << 'EOF'
on run {targetBuddy, messageText}
    tell application "Messages"
        set targetService to 1st service whose service type = iMessage
        set theBuddy to buddy targetBuddy of targetService
        send messageText to theBuddy
    end tell
end run
EOF
```

**Note**: The MessageResponder will automatically create this file if it doesn't exist, but you may need to manually create the directory first.

## Configuration

### External Program Path

To process attachments with an external program, configure the path in the MessageProcessor:

```swift
// In your setup code:
messageProcessor.externalProgramPath = "/path/to/your/processing/program"
```

Your processing program should:
- Accept a `--file <path>` argument
- Process the file
- Output the result to stdout
- Exit with code 0 on success

**Example processing program**:

```bash
#!/bin/bash
# save as ~/bin/process-attachment.sh

FILE_PATH=$2  # Second argument after --file

# Process the file (example: extract text from image)
tesseract "$FILE_PATH" stdout

# Or: analyze with AI, convert format, etc.
```

### Auto-Response (iMessage only)

Enable automatic responses:

```swift
messageProcessor.autoRespondEnabled = true
```

**Important**: Auto-response only works for iMessage. WeChat does not support programmatic message sending.

## Monitoring Behavior

### iMessage

✅ **Supported:**
- Real-time notification capture
- Sender identification
- Full message text extraction
- Attachment detection and file access
- Automated responses (requires AppleScript setup)

⚠️ **Limitations:**
- Requires existing conversation thread to send responses
- iCloud Messages sync doesn't affect notification capture

### WeChat

✅ **Supported:**
- Real-time notification capture
- Sender identification
- Attachment detection (if shown in notification)

⚠️ **Limitations:**
- Message text may be truncated in notifications
- **CANNOT send responses programmatically** (no API, TOS violation)
- Database is encrypted (notification monitoring is the only option)

## File Processing

### Attachment Storage

Attachments are automatically copied to:
```
~/Documents/VisualAgent/Processing/
```

Files are renamed with the pattern:
```
{bundle_id}_{timestamp}_{original_name}.{extension}
```

Examples:
- `com.apple.iChat_1696435200_image.jpg`
- `com.tencent.xinWeChat_1696435300_document.pdf`

### Processing Flow

1. **Notification arrives** with attachment indicator
2. **Pending queue** tracks expected file (10 second timeout)
3. **FSEvents monitors** filesystem for new files in:
   - `~/Library/Messages/Attachments/` (iMessage)
   - `~/Library/Containers/com.tencent.xinWeChat/.../` (WeChat)
4. **File matching** by bundle ID, timestamp proximity, and filename hint
5. **Copy to processing directory**
6. **Execute external program** with file path
7. **Optional response** (iMessage only) with program output

## UI Indicators

### Status Display

When message monitoring is active, you'll see:
- 🟢 Green indicator dot in the mini overlay bar
- 📱 Emoji indicator
- Tooltip: "Message monitoring active"

### Message History

The app tracks all processed messages including:
- Sender information
- Message text
- Attachment file paths
- Processing results
- Response status (sent/failed)

## Troubleshooting

### Issue: No notifications detected

**Solutions:**
1. Verify Accessibility permission is granted
2. Check that Messages/WeChat apps are running
3. Test by sending yourself a message
4. Check Console app for "📱 NotificationCenterObserver" logs

### Issue: Attachments not found

**Solutions:**
1. Verify Full Disk Access permission
2. Check file appears in notification (e.g., "📎 Image")
3. Increase timeout if files are slow to appear
4. Check processing directory for partial matches

### Issue: Can't send iMessage responses

**Solutions:**
1. Verify AppleScript exists at correct location
2. Check conversation thread exists in Messages.app
3. Test script manually:
   ```bash
   osascript ~/Library/Application\ Scripts/com.visualagent.VisualAgent/sendMessage.scpt "+1234567890" "Test message"
   ```

### Issue: Permission errors

**Solutions:**
1. Re-grant Accessibility permission
2. Restart Visual Agent after granting permissions
3. Check System Settings for any blocked requests

## Privacy & Security

### Data Storage

- **Notifications**: Stored in-memory only (not persisted to disk by default)
- **Attachments**: Copied to local processing directory
- **Message history**: Stored in app memory (cleared on quit)

### Network Activity

- **Zero network requests** - all processing is local
- No telemetry or analytics
- iMessage sending uses local Messages.app (no direct iCloud access)

### Permissions Summary

| Permission | Required For | Auto-Requested | Manual Setup |
|------------|-------------|----------------|--------------|
| Accessibility | Notification monitoring | ✅ Yes | System Settings |
| Full Disk Access | Attachment files | ❌ No | System Settings |
| Application Scripts | iMessage responses | ❌ No | Manual file creation |

## Testing

### Test iMessage Monitoring

1. Grant all permissions
2. Launch Visual Agent
3. Send yourself an iMessage with an image attachment
4. Check Console for log messages:
   ```
   📬 Received notification from: <sender> via iMessage
   📎 Has attachment: image
   📄 File created: <filename>
   ✅ Matched attachment: <filename> for <sender>
   💾 Copied attachment to: ~/Documents/VisualAgent/Processing/...
   ```

### Test WeChat Monitoring

1. Ensure WeChat is running
2. Have someone send you a WeChat message
3. Check for notification capture in logs
4. Note: WeChat responses are NOT supported

## Advanced Configuration

### Custom Attachment Processing

Implement your own processing logic:

```swift
messageProcessor.onAttachmentFound = { fileURL, attachment in
    print("Processing: \(fileURL.path)")

    // Your custom logic here
    // - OCR text extraction
    // - Image analysis with Vision/CoreML
    // - File format conversion
    // - Upload to cloud storage
    // etc.
}
```

### Filtering Messages

Add custom filtering in NotificationParser:

```swift
// Only process messages from specific senders
if !allowedSenders.contains(sender) {
    return nil
}
```

### Message Logging

Enable database persistence:

```swift
// Store message history in DatabaseManager
databaseManager.saveMessage(
    sender: notification.sender,
    text: notification.messageText,
    timestamp: notification.timestamp,
    app: notification.bundleID
)
```

## Known Issues & Limitations

1. **macOS Version**: Requires macOS 12.3+ for ScreenCaptureKit (existing requirement)
2. **Accessibility API Changes**: Apple may change notification UI structure in future macOS versions
3. **WeChat Responses**: No programmatic way to send WeChat messages (by design - TOS)
4. **Notification Truncation**: Long messages may be truncated in notifications
5. **File Timing**: Attachment files may take 1-3 seconds to appear after notification

## Future Enhancements

- [ ] Persistent message database
- [ ] Vector embeddings for semantic search
- [ ] LLM integration for smart responses
- [ ] Multi-language support (Chinese, etc.)
- [ ] Custom notification filters/rules
- [ ] Export message history (JSON/CSV)

## Support

For issues or questions:
1. Check console logs for detailed error messages
2. Verify all permissions are granted
3. Test with simple cases first (text-only messages)
4. Review this documentation for troubleshooting steps

---

**Last Updated**: October 2024
**Version**: 1.0.0
**Compatibility**: macOS 12.3+
