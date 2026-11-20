<div align="center">

# TypeMate

**A zero-dependency native macOS menu bar writing assistant & instant translator.**

[![macOS](https://img.shields.io/badge/macOS-15%2B-000000?logo=apple&logoColor=white)](https://github.com/rockcli/TypeMate)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

English | [简体中文](README.zh-CN.md)

</div>

## Features

- **Real-time English polishing in WeChat** — Monitors keystrokes via `CGEvent` (not WeChat's Accessibility tree, so it survives app updates) and floats 1–3 native alternatives after a configurable debounce (default `300ms`).
- **IME-aware** — Uses Carbon TIS (`TISCopyCurrentKeyboardInputSource`) to skip auto-capture automatically when a Chinese input method is active.
- **Instant bidirectional translation (`⌘C × 2`)** — Select any text in any app and double-press `⌘C` to translate Chinese ↔ English in a non-activating floating `NSPanel`.
- **Keyboard-first workflow** — Press `⌥1` / `⌥2` / `⌥3` to accept a suggestion (via Accessibility `AXValue` or clipboard fallback with full pasteboard restoration), or `Esc` to dismiss. Hovering pauses auto-dismiss (default `10s`, configurable in Settings).
- **Configurable LLM backend** — Uses DeepSeek's Anthropic-compatible `/v1/messages` API (`deepseek-flash` by default, with `deepseek-v4-pro` preset or any custom Base URL / Model in **Settings → API**).
- **Zero third-party dependencies** — Pure Swift 6, SwiftUI, AppKit, Carbon, and CoreGraphics.

## Architecture

```text
CGEvent Tap ──▶ Carbon TIS (skip Chinese IME) ──▶ Debounce ──▶ SuggestionCache
                                                                     │ (miss)
Double ⌘C ───▶ Pasteboard ──▶ Language Detection ────────────────────┴──▶ LLMService (/v1/messages)
                                                                                 │
                                           AXValue / Safe Clipboard ◀── Floating NSPanel (⌥1–3)
```

## Quick Start

Requires **macOS 15+** and **Xcode 16+ / Swift 6.0+**.

```bash
git clone https://github.com/rockcli/TypeMate.git
cd TypeMate
./scripts/install.sh
```

`./scripts/install.sh` builds the release binary, bundles `/Applications/TypeMate.app`, and ad-hoc signs it.

Launch directly from terminal (recommended for ad-hoc signed `CGEvent` apps so macOS TCC matches the current binary):

```bash
/Applications/TypeMate.app/Contents/MacOS/TypeMate &
```

### API Configuration

Open **TypeMate → Settings... (`⌘,`) → API** to set:

- **Base URL**: `https://api.deepseek.com/anthropic` (default)
- **Model**: `deepseek-flash` (default) or `deepseek-v4-pro`, or any custom Anthropic-compatible model ID
- **API Key**: stored in macOS Keychain (`com.typemate`)

Environment variables `ANTHROPIC_API_KEY` (highest priority) and `ANTHROPIC_AUTH_TOKEN` (fallback) are also supported.

### Permissions

Grant **Input Monitoring** (required for `CGEvent.tapCreate`) and **Accessibility** (required for `AXValue` text replacement and fallback synthetic `CGEvent.post` `⌘A`/`⌘V` paste) to `/Applications/TypeMate.app` in **System Settings → Privacy & Security**, then restart TypeMate.

> Note: Every ad-hoc rebuild changes the binary's CDHash, so macOS requires re-granting Input Monitoring after rebuilding.

## Debugging

```bash
TYPEMATE_DEBUG=1 /Applications/TypeMate.app/Contents/MacOS/TypeMate &
tail -f /tmp/typemate.log
```

## Non-Goals

- **Not a general-purpose IME or system-wide grammar suite** — Automatic input capture targets WeChat (`com.tencent.xinWeChat`) only; other apps are supported solely via explicit double-`⌘C` translation.
- **No automated test target yet** — `Package.swift` defines only the `TypeMate` executable target.
- **No cloud sync or telemetry backend** — Requests go strictly to your configured Anthropic-compatible `/v1/messages` endpoint.

## Known Pitfalls

- **WeChat must be running at launch** — `autoStartIfPossible()` checks for `com.tencent.xinWeChat` once on startup without a launch observer; start WeChat before TypeMate.
- **Mid-sentence cursor edits desync the buffer** — Blind `CGEvent` keystroke buffering ignores arrow keys (`123...126`), mouse cursor repositioning, range deletes, and pastes (`Esc` resets the buffer).
- **Chinese IME auto-skip** — Carbon TIS skips auto-capture whenever the active input source reports a `zh*` language prefix; select Chinese text and double-press `⌘C` to translate.
- **Accepting outside a text box (`⌥1/2/3`)** — If `AXValue` replacement fails, `TextReplacer` falls back to posting global `⌘A` + `⌘V` (restoring the prior pasteboard after `0.5s`); only accept suggestions while focused inside an input field.
- **Ad-hoc CDHash & `open` trap** — Rebuilding changes the ad-hoc CDHash and invalidates Input Monitoring TCC; launch `/Applications/TypeMate.app/Contents/MacOS/TypeMate` directly instead of `open /Applications/TypeMate.app`.

## Security & Trust Boundaries

- **Required TCC permissions** — Uses **Input Monitoring** (`CGEvent.tapCreate` and global shortcuts), **Accessibility** (`AXUIElement` replacement and synthetic `CGEvent.post` paste), and `CGWindowListCopyWindowInfo` (on-screen window PID/bounds only for panel docking).
- **Network egress scope** — Sends text exclusively to your configured `/v1/messages` endpoint (default `https://api.deepseek.com/anthropic/v1/messages`, model `deepseek-flash`): (1) English drafts typed in WeChat (≥3 words, capped at `500` chars after debounce) and (2) clipboard text on explicit double-`⌘C` (capped at `500` chars). Non-WeChat keystrokes and Chinese IME keystrokes are neither buffered nor uploaded.
- **Credentials & debug logging** — API keys saved via **Settings → API** are stored in macOS Keychain (`com.typemate` / `deepseek-api-key`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). Enabling `TYPEMATE_DEBUG=1` writes plaintext WeChat input buffers, clipboard excerpts (up to 60 chars), and LLM suggestion previews to `/tmp/typemate.log` — keep it disabled outside local troubleshooting.

## License

[MIT](LICENSE) © [rockcli](https://github.com/rockcli)
