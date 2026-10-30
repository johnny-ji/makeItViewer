# Electron Windows 迁移设计

## 目标

以 Electron 替换 Windows 版 Python/pywebview 宿主，保留现有 Markdown 与 Mermaid 查看体验，并消除 WebView 桥接初始化导致的文件选择器失效。

## 架构

- `electron/main.js`：创建 BrowserWindow；实现原生打开/保存对话框、文件读取、文件监控、图像剪贴板与打印。
- `electron/preload.js`：通过 `contextBridge` 暴露最小化 `window.viewer` API。保持 `contextIsolation: true`、`nodeIntegration: false`。
- `electron/renderer/`：承载并逐步迁移当前 `resources/index.html`、离线 Marked 与 Mermaid 资源；只负责界面、渲染和调用 `window.viewer`。

## 数据流

用户点击“打开文件”后，渲染进程调用 `viewer.openFile()`；主进程以 `dialog.showOpenDialog` 显示 Windows 原生文件框，读取选定文件并返回文件名、路径与内容。主进程启动 `fs.watch` 监控该路径，内容变化时主动通知渲染进程刷新。保存 SVG/PNG、复制图片和打印同样由受控 IPC 处理。

## 安全与稳定性

渲染器不得访问 Node.js、`ipcRenderer` 或磁盘路径以外的任意主进程能力。预加载脚本只公开固定方法与数据结构。所有 IPC 参数在主进程校验；文件类型限制为 Markdown/文本，写入仅由用户选择保存位置后发生。

## 打包与验收

使用 `electron-builder` 产出 Windows 便携 EXE 与 NSIS 安装包。验收包括：首次启动可立即打开文件；快速重复点击仅产生一个对话框；拖拽打开；外部修改自动刷新；中文 Mermaid 正确显示；PNG/SVG 导出、剪贴板复制与打印可用。
