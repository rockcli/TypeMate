<div align="center">

# TypeMate

**零第三方依赖的原生 macOS 菜单栏英文写作助手与即时翻译工具。**

[![macOS](https://img.shields.io/badge/macOS-15%2B-000000?logo=apple&logoColor=white)](https://github.com/rockcli/TypeMate)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[English](README.md) | 简体中文

</div>

## 功能特性

- **微信英文实时润色** — 基于 `CGEvent` 全局键盘监听（不依赖微信内部 Accessibility 树，不受微信版本升级影响），英文输入法下停顿后（默认 `300ms`，可调）自动在微信窗口旁弹出 1–3 条更地道的表达建议。
- **输入法自动感知** — 通过 Carbon TIS（`TISCopyCurrentKeyboardInputSource`）识别当前输入法，中文输入状态下自动跳过捕获，不误抓拼音。
- **任意应用双击 `⌘C` 即时互译** — 选中任意中文或英文文本，连续按两次 `⌘C`，自动识别语种并弹出中 ↔ 英翻译悬浮面板。
- **纯键盘流操作** — 面板弹出后按 `⌥1` / `⌥2` / `⌥3` 一键替换或上屏（优先 `AXValue` 写入，不可写时自动走完整保留原剪贴板内容的粘贴回退），`Esc` 关闭；鼠标悬停暂停自动消失（默认 `10s`，可在设置中调整）。
- **可自定义 LLM 后端与模型** — 默认对接 DeepSeek Anthropic 兼容接口（`https://api.deepseek.com/anthropic`，默认模型 `deepseek-flash`，内置 `deepseek-v4-pro` 快捷切换，也支持在 **Settings → API** 中自定义任意 Base URL 与模型名）。
- **零第三方依赖** — 纯 Swift 6、SwiftUI、AppKit、Carbon 与 CoreGraphics 实现。

## 工作原理

```text
CGEvent Tap ──▶ Carbon TIS (中文输入法自动跳过) ──▶ Debounce ──▶ SuggestionCache
                                                                       │ (未命中)
双击 ⌘C ──────▶ 读取剪贴板 ──▶ 中英自动识别 ───────────────────────────┴──▶ LLMService (/v1/messages)
                                                                                   │
                                                 AXValue / 安全剪贴板回退 ◀── 悬浮 NSPanel (⌥1–3)
```

## 快速安装

需要 **macOS 15+** 与 **Xcode 16+ / Swift 6.0+**。

```bash
git clone https://github.com/rockcli/TypeMate.git
cd TypeMate
./scripts/install.sh
```

`./scripts/install.sh` 会自动完成 Release 编译、组装 `/Applications/TypeMate.app` 并执行 ad-hoc 签名。

建议从终端直接启动二进制文件（避免 Launch Services 缓存旧签名策略导致 `CGEvent.tapCreate` 权限失效）：

```bash
/Applications/TypeMate.app/Contents/MacOS/TypeMate &
```

### API 与模型配置

点击菜单栏图标 → **Settings...（`⌘,`）→ API** 即可配置：

- **Base URL**：默认 `https://api.deepseek.com/anthropic`
- **Model**：默认 `deepseek-flash`（可选 `deepseek-v4-pro` 或填写任意自定义模型 ID）
- **API Key**：安全存储在 macOS 钥匙串（`com.typemate`）中

同时也支持通过环境变量 `ANTHROPIC_API_KEY`（最高优先级）或 `ANTHROPIC_AUTH_TOKEN` 传入 Key。

### 系统权限

在 **系统设置 → 隐私与安全性** 中为 `/Applications/TypeMate.app` 授予：

- **输入监控（Input Monitoring）**：必需，用于 `CGEvent` 键盘监听；授权后需重启 TypeMate 生效。
- **辅助功能（Accessibility）**：可选，用于直接通过 `AXValue` 替换微信输入框文本（未开启时自动回退到安全剪贴板粘贴）。

> 提示：每次重新 ad-hoc 编译都会改变二进制文件的 CDHash，若重新构建后监听失效，请在系统设置中重新勾选/拖入 `/Applications/TypeMate.app` 并重启应用。

## 调试日志

```bash
TYPEMATE_DEBUG=1 /Applications/TypeMate.app/Contents/MacOS/TypeMate &
tail -f /tmp/typemate.log
```

## License

[MIT](LICENSE) © [rockcli](https://github.com/rockcli)
