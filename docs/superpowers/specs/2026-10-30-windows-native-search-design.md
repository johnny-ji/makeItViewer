# Windows 原生页面检索设计

## 意图

为 Windows Electron 查看器加入不区分大小写的页面检索，使用户能在 Markdown 正文及 Mermaid 渲染后的原生 SVG 标签中定位文字，并由 Chromium 提供原生高亮。

## 目标

- 通过 `Ctrl+F` 打开一个应用内检索栏。
- 输入关键词时调用 Electron `webContents.findInPage`，显示当前项与匹配总数。
- 支持 Enter / Shift+Enter 或按钮在结果间前后跳转；Esc 关闭并清除检索选择。
- Markdown 重渲染和 Mermaid 异步渲染完成后，若检索栏仍有关键词，自动重新开始检索。
- 所有 renderer 到主进程的能力继续通过 `preload.js` 白名单暴露，保持 `contextIsolation: true` 与 `nodeIntegration: false`。

## 非目标

- 不实现自定义 `<mark>` 高亮、正则表达式、大小写切换或跨文件检索。
- 不修改 Markdown 源文本或导出的 SVG/PNG。
- 不保证 Chromium 原生高亮的颜色与外观可配置。

## 约束

- 仅修改 `electron/` 的 Windows Electron 实现；不改变 macOS 查看器。
- Mermaid 仍使用原生 SVG 文本（`htmlLabels: false`），以便原生页面检索覆盖其标签。
- 空关键词不调用 `findInPage`，而是调用 `stopFindInPage('clearSelection')`。

## 方案比较

1. **Electron 原生 `webContents.findInPage`（已选）**：搜索整个已渲染页面，通常可包含 Mermaid SVG 文字；支持匹配数量、前后导航及原生高亮。代价是高亮样式由 Chromium 决定，并需在内容重建后重新发起查询。
2. **Renderer 文本节点标记**：高亮样式可控，但需要避开或特别处理 SVG、代码块和 Mermaid 动态 DOM，无法满足优先覆盖图表文字的目标。
3. **浏览器内建查找 UI**：不需要开发，但没有应用内一致的工具栏与状态反馈。

## 架构与交互

- `main.js` 监听 `webContents` 的 `found-in-page` 事件，并将最终结果（请求 ID、当前匹配序号、总匹配数）推送给 renderer。
- `main-handlers.js` 注册 IPC：开始或继续检索、结束检索。主进程固定 `matchCase: false`，将前/后方向与新查询状态映射为 `findInPage` 选项。
- `preload.js` 仅暴露 `findInPage`、`stopFindInPage` 和 `onFindResult`。
- `renderer/index.html` 增加可访问的检索栏。输入更改启动新检索；Enter/Shift+Enter 和导航按钮继续当前检索；Esc 清除选择并关闭。接收结果后显示 `当前/总数` 或“未找到”。
- `updateMarkdown()` 在 Mermaid 渲染循环结束后调用 renderer 侧的重新检索函数；不修改或重新解析页面来实现高亮。

## 验收标准

- 打开含普通正文和 Mermaid 标签的 Markdown，按 `Ctrl+F` 输入文字后显示原生高亮及正确匹配数。
- 输入大小写不同的同一关键词，仍能匹配。
- 前后导航可循环/移动 Chromium 当前选择；关闭或清空时高亮选择被清除。
- 文件热更新后，检索栏不关闭，文档更新完成后自动恢复当前关键词的检索。
- Electron 单元测试覆盖 IPC 选项、preload 白名单、渲染器契约以及重渲染后恢复检索的契约。
