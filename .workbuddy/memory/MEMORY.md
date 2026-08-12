# Cut Paste 项目长期记忆

## 项目概况
- macOS 剪贴板管理应用（Swift Package Manager + AppKit）
- Bundle ID: `io.github.wowworld.cutpaste`（7/6 从 `com.wangliang.CutPaste` 改过来）
- 开发者证书: `Apple Development: 657395646@qq.com (5Z2LXQ64LU)`, TeamID `BZC44NAUXS`
- 构建: `script/build_and_run.sh`，产物在 `dist/Cut Paste.app`
- 用户机器: macOS 26.3 (Tahoe), SIP enabled, arm64

## 关键约定
- 本地开发用 Apple Development 证书签名（非 Developer ID，未公证）
- 辅助功能权限是核心需求（用于发送 Cmd+V 粘贴）
- 已加 AppleScript fallback 走 Automation 权限作为备选

## 已知坑
- **每次重新构建后 CDHash 变化**，会导致 TCC 辅助功能授权失效（macOS 对未公证应用的硬性限制）
- **不要用 `cp` 替换二进制再重签**（fix-tcc.sh 的做法），会让 CDHash 每次都变，TCC 彻底混乱
- **dist 和 dist2 共存会导致 LaunchServices 注册冲突**，trustedCodeSignatures 与实际运行的 app 不匹配时，TCC 拒绝授权，"手动添加也不行"
- macOS 26.3 (Tahoe) 对未公证应用的 TCC 策略更严格
