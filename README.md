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

Grant **Input Monitoring** (required for `CGEvent.tapCreate`) and **Accessibility** (optional, for direct `AXValue` text replacement; falls back to safe clipboard paste otherwise) to `/Applications/TypeMate.app` in **System Settings → Privacy & Security**, then restart TypeMate.

> Note: Every ad-hoc rebuild changes the binary's CDHash, so macOS requires re-granting Input Monitoring after rebuilding.

## Debugging

```bash
TYPEMATE_DEBUG=1 /Applications/TypeMate.app/Contents/MacOS/TypeMate &
tail -f /tmp/typemate.log
```

## License

[MIT](LICENSE) © [rockcli](https://github.com/rockcli)
