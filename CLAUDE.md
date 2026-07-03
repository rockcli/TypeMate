# TypeMate — macOS Menu Bar English Writing Assistant

## Build & Deploy

```bash
# Build
swift build -c release

# Deploy to /Applications (MUST copy Info.plist + re-sign!)
BINARY=$(swift build -c release --show-bin-path)/TypeMate
cp "$BINARY" /Applications/TypeMate.app/Contents/MacOS/TypeMate
cp EnglishHelper/Info.plist /Applications/TypeMate.app/Contents/
codesign --force --deep -s - /Applications/TypeMate.app

# ⚠️ NEVER use `open` to launch — it goes through Launch Services which caches
# stale security policies and blocks the event tap. Launch the binary DIRECTLY:
EH_DEBUG=1 /Applications/TypeMate.app/Contents/MacOS/TypeMate &

# Logs → /tmp/eh.log (only when EH_DEBUG=1 is set)
```

> **⚠️ Every rebuild = new ad-hoc CDHash → macOS revokes TCC permissions.**
> After replacing the binary, the user MUST re-grant Input Monitoring permission AND restart the app.
> If Launch Services gets confused after multiple rebuilds, reset it:
> ```bash
> /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -domain local -domain system -domain user
> ```

## Permission Model (critical — this is the #1 source of bugs)

| Permission | TCC Service | Checked By | Needed For |
|---|---|---|---|
| **Input Monitoring** | `kTCCServiceListenEvent` | `CGEvent.tapCreate` | Keyboard event tap via `.cgSessionEventTap` |
| **Accessibility** | `kTCCServiceAccessibility` | `AXIsProcessTrusted()` | `TextReplacer.replaceViaAX()` |

**These are DIFFERENT permissions.** `CGEvent.tapCreate` does NOT check `AXIsProcessTrusted()`.
The app can log `AXIsProcessTrusted = false` while still having a working event tap (`START tap OK`).

**Input Monitoring has no "+" button in System Settings.** Users must drag the app from Finder into the list.
After granting, the app MUST be restarted — TCC changes only take effect on next process launch.

Debug commands:
```bash
tccutil reset All com.typemate.app          # Reset all TCC permissions for our bundle
tccutil reset ListenEvent com.typemate.app   # Reset just Input Monitoring
```

## The `open` Command Trap

`open /Applications/TypeMate.app` routes through Launch Services, which caches code-signing identity
and security policies. If Launch Services has stale state (e.g. from a previous binary with different
CDHash), `CGEvent.tapCreate` will fail even if Input Monitoring permission is correctly granted.

**Always launch directly:**
```bash
EH_DEBUG=1 /Applications/TypeMate.app/Contents/MacOS/TypeMate &
```

## App Structure

```
EnglishHelper/              ← source directory (historical name, kept for compatibility)
  EnglishHelperApp.swift      ← @main entry, MenuBarExtra, LSUIElement (.accessory policy)
  PipelineCoordinator.swift   ← central orchestrator, listens for .apiKeyUpdated notification
  Monitor/HybridMonitor.swift ← CGEvent tap + double Cmd+C hotkey
    - Temporarily switches to .regular activation policy before tap creation
      so macOS can show the Input Monitoring permission dialog if needed
  LLM/LLMService.swift        ← DeepSeek API (Anthropic-compatible /v1/messages)
  UI/SuggestionPanelController.swift ← NSPanel floating window (borderless, nonactivating)
  Services/ConfigurationManager.swift ← UserDefaults + Keychain
```

Naming conventions:
- Package/Swift target: **TypeMate**
- Bundle ID: `com.typemate.app`
- Source directory: `EnglishHelper/` (historical, OK to keep)
- Notification prefix: `com.typemate.*`
- Keychain service: `com.typemate`
- Debug env var: `EH_DEBUG=1`
- Old type names (`EnglishHelperApp`, `EnglishHelperError`) are cosmetic — rename only if touching that file anyway

## API Key Loading

Priority order in `ConfigurationManager.getAPIKey()`:
1. Env var `ANTHROPIC_API_KEY`
2. Keychain (service `com.typemate`, account `deepseek-api-key`)
3. Env var `ANTHROPIC_AUTH_TOKEN`

If the app starts without an API key, `llmService` stays nil. Saving a key from Settings posts
`.apiKeyUpdated` notification → `PipelineCoordinator` picks it up and calls `setupLLMService()`
immediately — no restart needed anymore.

## Excluded from Build

These files are in `Package.swift` exclude list:
- `Monitor/ClipboardMonitor.swift`
- `UI/MenuBarController.swift`
