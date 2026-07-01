# TypeMate

> macOS 英文写作助手 — 在微信等应用中实时提供翻译和润色建议

[English](#english) | [安装](#安装) | [使用](#使用) | [已知问题](#已知问题)

---

## 这是什么

TypeMate 是一个 macOS 菜单栏应用。在微信里打英文时**自动弹出润色建议**，选中任意文字**双击 ⌘C 翻译**。零第三方依赖，纯 Apple 原生框架。

## 功能

| 模式 | 触发方式 | 效果 |
|------|----------|------|
| 英文润色 | 英文输入法下，在微信里打英文 | 300ms 后自动弹出更地道的表达 |
| 中→英翻译 | 选中中文 → 双击 ⌘C | 弹出英文翻译 |
| 英→中翻译 | 选中英文 → 双击 ⌘C | 弹出中文翻译 |

面板出现后用 **⌥1/2/3** 采纳建议，Esc 关闭。

## 系统要求

- macOS 14+ (Sonoma / Sequoia)
- Xcode 16+（编译用）
- DeepSeek API Key（[注册获取](https://platform.deepseek.com)）

## 安装

```bash
git clone https://github.com/rockcli/TypeMate.git
cd TypeMate
swift build -c release

# 创建 .app 包
mkdir -p /Applications/TypeMate.app/Contents/MacOS
cp .build/release/TypeMate /Applications/TypeMate.app/Contents/MacOS/TypeMate

cat > /tmp/tm.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>TypeMate</string>
    <key>CFBundleIdentifier</key><string>com.typemate.app</string>
    <key>CFBundleName</key><string>TypeMate</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
cp /tmp/tm.plist /Applications/TypeMate.app/Contents/Info.plist

# 启动（需传入 API Key）
ANTHROPIC_AUTH_TOKEN=sk-your-key-here \
  /Applications/TypeMate.app/Contents/MacOS/TypeMate &
```

或者永久设置：

```bash
echo 'export ANTHROPIC_AUTH_TOKEN="sk-your-key-here"' >> ~/.zshrc
```

## 使用

| 你在做什么 | TypeMate 做什么 |
|------------|----------------|
| 英文输入法 + 微信聊天框打字 | 自动弹出润色面板 |
| 切到中文输入法打中文 | **不自动触发**（避免抓拼音） |
| 选中任何文字 → 双击 ⌘C | 翻译面板弹出 |

**面板快捷键：** ⌥1 第一建议 · ⌥2 第二建议 · ⌥3 第三建议 · Esc 关闭

鼠标悬停在面板上暂停自动消失，移开后 10 秒自动关闭。

## 支持的微信版本

| 版本 | 状态 | 说明 |
|------|------|------|
| WeChat 4.1.8 (macOS) | ✅ 已测试 | 英文自动润色可用 |
| WeChat 4.x 系列 | ✅ 理论兼容 | 基于 CGEvent 键盘监听，不依赖微信内部 API |
| 微信 3.x | ⚠️ 未测试 | CGEvent 方案理论通用 |

**注意：** TypeMate 使用 `CGEvent` 全局键盘监听，**不依赖微信的 Accessibility API**。这意味着它不受微信版本升级导致的 AX 树变化影响。唯一的要求是 macOS 授予辅助功能权限。

## 已知问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 中文输入法无法自动翻译 | CGEvent 只能捕获拼音字母，拿不到组合后的中文 | 选中中文 → 双击 ⌘C 手动翻译 |
| 偶尔出现 "Empty response" | DeepSeek API 瞬时限流 | 稍等几秒重新触发 |
| 首次翻译较慢（5-8 秒） | API 冷启动 | 后续调用通常在 1-2 秒内 |
| 需要终端启动 | 未签名应用，需从终端 launch 继承权限 | `brew install` 或 launchd plist |

## 调试

```bash
EH_DEBUG=1 ANTHROPIC_AUTH_TOKEN=sk-... /Applications/TypeMate.app/Contents/MacOS/TypeMate &
tail -f /tmp/eh.log
```

## 技术架构

```
CGEvent Tap → 键盘事件捕获 → 英文自动识别 → 300ms 防抖 → DeepSeek API
                                            ↓
双击 ⌘C → 剪贴板读取 → 中英自动检测 → DeepSeek API
                                            ↓
                                    NSPanel 浮动面板
                                    (SwiftUI + AppKit)
```

- **CGEvent.tapCreate** 全局键盘监听，无需 Accessibility API
- **Carbon TIS** 检测当前输入法，中文输入法下自动跳过
- **DeepSeek API**（Anthropic 兼容端点），`thinking: disabled` 加速响应
- **NSPanel** 浮动窗口，紧贴微信右侧，右边不够自动翻到左边

## License

MIT

---

## English

**TypeMate** is a macOS menu bar app for English writing assistance. It provides real-time polishing suggestions while you type English in WeChat, and instant translation when you select text and double-press ⌘C.

### Quick Start

1. Get a [DeepSeek API key](https://platform.deepseek.com)
2. Build with `swift build -c release`
3. Launch with `ANTHROPIC_AUTH_TOKEN=sk-... /Applications/TypeMate.app/Contents/MacOS/TypeMate &`
4. Type English in WeChat → suggestions appear. Select text + double ⌘C → translation.

### Supported WeChat Versions

Tested on WeChat 4.1.8 (macOS). Uses CGEvent keyboard monitoring — does NOT depend on WeChat's internal Accessibility tree, so it survives version upgrades.

### Known Limitations

- Chinese IME auto-detection is not supported (CGEvent limitation). Use double ⌘C for Chinese translation.
- Unsigned app requires terminal launch or launchd plist for accessibility permissions.

### Tech Stack

Swift 6, SwiftUI + AppKit, CGEvent, Carbon TIS. Zero third-party dependencies.
