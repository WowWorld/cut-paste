# Cut Paste

一个 macOS 剪贴板管理工具，让你高效地回溯、搜索和粘贴历史剪贴板内容（复刻收费APP：Paste）。

## 功能

- **自动捕获**：自动记录复制的文本、链接、图片、文件和颜色值
- **Shelf 浮窗**：按 `⌘⇧V` 呼出底部浮窗，浏览和选择历史内容
- **快速粘贴**：选中内容后自动切回上一个 App 并粘贴，无需手动 `⌘V`
- **分类筛选**：All / Links / Images / Files / Colors / Pinned 六个标签页
- **实时搜索**：跨所有分类搜索历史内容
- **固定内容**：右键 Pin 或手动添加永久保留的内容，不受历史数量限制
- **快捷键粘贴**：浮窗内按 `⌘1`~`⌘9` 快速粘贴对应位置的内容
- **去重**：相同内容自动去重并提升到顶部
- **持久化**：重启后历史记录不丢失，图片独立存储

## 截图

<!-- TODO: 添加截图 -->

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Apple Silicon / Intel

## 安装

### 方式一：下载安装包（推荐）

1. 前往 [Releases](../../releases) 页面
2. 下载最新的 `CutPaste.zip`
3. 解压后将 **Cut Paste.app** 拖入 `应用程序` 文件夹
4. 首次打开时，macOS 会提示 **"无法打开，因为无法验证开发者"**：
   - **方法 A**：右键点击 **Cut Paste.app** → 选择 **"打开"** → 在弹出的对话框中点 **"打开"**
   - **方法 B**：打开终端，运行 `xattr -cr "/Applications/Cut Paste.app"`
5. 授予**辅助功能权限**：
   - 打开 **系统设置 → 隐私与安全性 → 辅助功能**
   - 找到 **Cut Paste**，打开开关
6. 按 `⌘⇧V` 开始使用

### 方式二：从源码构建

```bash
git clone https://github.com/WowWorld/cut-paste.git
cd cut-paste
bash script/build_and_run.sh
```

## 使用方法

| 快捷键 | 功能 |
|--------|------|
| `⌘⇧V` | 呼出 / 隐藏 Shelf 浮窗 |
| `⌘1` ~ `⌘9` | 快速粘贴对应位置的内容 |
| `Enter` | 粘贴当前选中项 |
| `⌘⌥C` | 手动捕获当前剪贴板 |
| `Esc` | 关闭浮窗 |
| 输入任意文字 | 自动进入搜索 |

### 固定内容

- **右键 Pin**：将复制的内容固定，仅在 Pinned 标签展示
- **手动添加**：点击浮窗左上角"添加"按钮，输入要永久保留的内容（支持文本、链接、颜色值）

### 分类说明

| 标签 | 内容 |
|------|------|
| All | 全部历史记录（不含手动添加的固定项） |
| Links | 链接 |
| Images | 图片 |
| Files | 文件路径 |
| Colors | 十六进制颜色值 |
| Pinned | 所有固定项（含手动添加） |

## 权限说明

| 权限 | 用途 |
|------|------|
| 辅助功能 (Accessibility) | 模拟 `⌘V` 按键实现自动粘贴 |

> 如果权限未生效，可运行 `bash fix-tcc.sh` 重置权限记录后重新授权。

## 数据存储

| 路径 | 内容 |
|------|------|
| `~/Library/Application Support/CutPaste/ClipboardHistory.json` | 历史记录元数据 |
| `~/Library/Application Support/CutPaste/Images/` | 图片文件 |

## 技术栈

- Swift 5.10 + SwiftUI + AppKit
- Carbon Framework（全局热键）
- CryptoKit（内容指纹去重）
- 零第三方依赖

## License

MIT
