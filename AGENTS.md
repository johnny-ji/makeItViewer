# Repository Guidelines（仓库协作指南）

## 项目概览与结构

当前仓库维护两个可运行的桌面实现：

- `electron/`：Windows 优先的 Electron 应用。`main.js` 管理窗口、单实例和启动文件，`preload.js` 通过 `contextBridge` 暴露受限 API，`src/` 包含文件读取/编码兼容、文件监听、启动参数和 IPC 处理，`renderer/` 包含 Markdown/Mermaid 页面及离线 vendor 资源。
- `macos-viewer/`：原生 macOS 实现。`src/main.swift` 使用 Cocoa/WebKit，`resources/` 存放页面和离线资源，`Info.plist` 声明应用信息及文件关联，`build.sh` 构建 App，`package.sh` 构建通用架构发布包。

`docs/superpowers/` 保存迁移设计、计划和执行记录。仓库中目前没有 `windows-viewer/` Python 实现，也没有统一的根目录构建脚本。

生成目录包括 `electron/node_modules/`、`electron/release/`、`electron/tools/nsis-3.0.4.1/`、`macos-viewer/dist/` 以及 macOS 构建产生的临时文件；不要手工修改或提交其中的构建产物。`package-lock.json` 是依赖锁文件，依赖变更时应与 `package.json` 一起更新。

## 构建、运行与测试

### Electron（Windows）

在 `electron/` 目录执行：

```powershell
npm ci                 # 按 package-lock.json 安装依赖
npm start              # 启动开发应用
npm test               # 运行 Node 内置测试
npm run dist           # 生成 NSIS 安装包和 portable EXE
```

也可以执行 `build.bat` 完成依赖安装和打包。该脚本要求先将 `tools/nsis-3.0.4.1.7z` 解压为 `tools/nsis-3.0.4.1/`，并通过 `ELECTRON_BUILDER_NSIS_DIR` 指向该目录。打包输出位于 `electron/release/`。

Electron 支持通过命令行打开 `.md`/`.markdown` 文件，也支持文件选择和拖放；读取时兼容 UTF-8 BOM，并在检测到替换字符时回退到 GB18030。渲染器使用本地 `marked.min.js` 和 `mermaid.min.js`，提供 Mermaid 图表的缩放、平移、全屏查看、PNG 复制/导出，以及打印/PDF 和全宽模式。

### macOS

在 macOS 上从 `macos-viewer/` 执行：

```bash
./build.sh       # 构建当前机器架构的 MarkdownViewer.app
./package.sh     # 构建 arm64 + x86_64 通用 App，并生成 ZIP 和 DMG
```

`build.sh` 直接使用 `swiftc` 编译 Cocoa/WebKit 应用；`package.sh` 还需要 `lipo`、`codesign`、`ditto` 和 `hdiutil`。输出位于 `macos-viewer/dist/`。macOS 实现同样支持打开/拖放 Markdown、实时监听、Mermaid 图表交互和导出；修改共享页面行为时应分别验证 Electron 的 IPC 路径和 macOS 的 WebKit 消息桥接。

## 测试与验证

Electron 测试使用 Node 内置测试运行器，文件位于 `electron/tests/`，命名为 `*.test.js`，覆盖文件读取/监听、启动参数、preload 白名单 API 和 renderer 合约。提交 Electron 改动至少运行：

```powershell
cd electron
npm test
```

涉及 UI、文件系统或打包的改动还应手动验证：打开文件对话框、命令行文件关联、拖放、文件热加载、UTF-8/GB18030 文本、Mermaid 渲染与错误显示、图表缩放/平移/适应窗口、PNG/SVG 导出、复制、打印/PDF、单实例行为及窗口关闭。macOS 改动应在 macOS 上重新执行相应构建脚本并至少打开一个 Markdown 文件；仓库当前没有 Python 测试或 Swift 自动化测试配置。

## 编码与修改约定

JavaScript、HTML 和 CSS 延续现有风格：小范围、可读的修改，使用清晰的 `camelCase` 函数/变量名；主进程与渲染器之间的新能力必须经过 `preload.js` 白名单 API，不要重新启用 renderer 的 Node 集成。文件服务、IPC 和原生系统集成中的非显而易见逻辑应补充简短注释。

Swift 延续现有 4 空格缩进和 `camelCase` 命名。Cocoa/WebKit 生命周期、拖放和脚本消息处理改动应避免阻塞主线程，并同步检查 `Info.plist`、资源复制和打包脚本。

离线 `marked.min.js`、`mermaid.min.js` 是应用运行时资源；升级时记录来源和版本，并同步 Electron 与 macOS 所需副本。不要把用户 Markdown 文件、个人绝对路径、签名材料、密钥或构建产物加入仓库。

## 提交与交付检查

当前检出目录没有可用的 Git 提交历史，不能据此推断既有提交格式。建议使用简短、祈使语气的单一目的提交标题，例如 `修复 Mermaid 导出` 或 `Update macOS packaging`。

提交或交付说明应包含：目标平台、行为变化、实际运行的验证命令、手动测试范围、已知限制，以及新增依赖或资源版本。涉及 UI 或安装包时附截图/短视频，并明确说明是否重新生成了 `release/` 或 `dist/` 产物。
