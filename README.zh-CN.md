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

- **输入监控（Input Monitoring）**：必需，用于 `CGEvent.tapCreate` 键盘监听；授权后需重启 TypeMate 生效。
- **辅助功能（Accessibility）**：用于直接通过 `AXValue` 替换微信输入框文本及回退发送合成 `CGEvent.post`（`⌘A` / `⌘V`）粘贴。

> 提示：每次重新 ad-hoc 编译都会改变二进制文件的 CDHash，若重新构建后监听失效，请在系统设置中重新勾选/拖入 `/Applications/TypeMate.app` 并重启应用。

## 调试日志

```bash
TYPEMATE_DEBUG=1 /Applications/TypeMate.app/Contents/MacOS/TypeMate &
tail -f /tmp/typemate.log
```

## 非目标

- **非通用输入法或全局语法校验插件** — 自动键盘监听润色仅针对微信（`com.tencent.xinWeChat`），其他应用仅响应显式双击 `⌘C` 划词翻译。
- **暂未包含自动化测试目标** — `Package.swift` 当前仅定义了 `TypeMate` 可执行目标。
- **无云端同步或遥测后台** — 文本请求仅直连你配置的 Anthropic 兼容 `/v1/messages` 接口。

## 已知坑点

- **启动时微信必须已在运行** — `autoStartIfPossible()` 仅在启动时检查一次 `com.tencent.xinWeChat` 进程（无后台启动监听），请先打开微信再启动 TypeMate。
- **句中移动光标或粘贴会造成缓冲漂移** — 盲记按键缓冲会忽略方向键（`123...126`）、鼠标点击改光标、范围删除与粘贴操作，按 `Esc` 可清空缓冲。
- **中文输入法自动跳过** — 检测到当前输入法语言前缀为 `zh*` 时（Carbon TIS），会自动跳过捕获；中文请选中文本后双击 `⌘C` 翻译。
- **非输入框焦点下按 `⌥1/2/3` 采纳风险** — 若 `AXValue` 写入失败，`TextReplacer` 会回退发送全局 `⌘A` + `⌘V`（`0.5s` 后恢复原剪贴板），请仅在微信输入框聚焦时按快捷键采纳。
- **重编译后签名哈希失效与 `open` 陷阱** — 每次重编译都会改变 ad-hoc CDHash 并使输入监控权限失效，请直接运行 `/Applications/TypeMate.app/Contents/MacOS/TypeMate` 而不要使用 `open /Applications/TypeMate.app`。

## 安全与信任边界

- **系统权限范围** — 需要 macOS **输入监控**（`CGEvent.tapCreate` 与全局快捷键）、**辅助功能**（`AXUIElement` 替换及合成 `CGEvent.post` 粘贴）和 `CGWindowListCopyWindowInfo`（仅读取屏幕上窗口 PID 与边界坐标用于面板停靠）。
- **出境数据范围** — 仅向配置的 `/v1/messages` 接口（默认 `https://api.deepseek.com/anthropic/v1/messages`，模型 `deepseek-flash`）发送两类文本：（1）微信前台英文输入草稿（≥3 词，防抖后截断至 `500` 字符）；（2）显式双击 `⌘C` 时的剪贴板文本（截断至 `500` 字符）。非微信应用的普通按键与中文输入法按键不会被缓冲或上传。
- **凭据存储与调试日志警示** — 通过 **Settings → API** 保存的 API Key 存储在 macOS 钥匙串（`com.typemate` / `deepseek-api-key`，`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`）。开启 `TYPEMATE_DEBUG=1` 会将明文微信输入缓冲、剪贴板片段（最多 60 字符）与模型返回预览写入 `/tmp/typemate.log`，日常使用请保持关闭。

## License

[MIT](LICENSE) © [rockcli](https://github.com/rockcli)
