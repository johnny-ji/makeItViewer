# Windows Native Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Windows Electron find bar that uses Chromium native page search, including Mermaid SVG text.

**Architecture:** The renderer owns the find bar and keyboard UX. Main process code owns `webContents.findInPage` and returns final `found-in-page` status through the existing context-isolated IPC bridge. After Markdown and Mermaid asynchronously redraw, the renderer restarts any active query rather than changing DOM content to highlight it.

**Tech Stack:** Electron 39, Node.js built-in test runner, vanilla HTML/CSS/JavaScript.

**Spec:** `docs/superpowers/specs/2026-10-30-windows-native-search-design.md`

## Global Constraints

- Modify only `electron/`; retain `contextIsolation: true` and `nodeIntegration: false`.
- Expose new native operations only through the `preload.js` whitelist.
- Force `matchCase: false`; an empty query or explicit close uses `stopFindInPage('clearSelection')`.
- Do not edit generated assets, `node_modules/`, or release artifacts.

## Review Focus

- Whitespace-only input clears selection without calling `findInPage`.
- Follow-up navigation retains the existing Chromium session with `findNext: false`.
- Stale result events cannot replace the status for a newer request.
- Reload starts the active query only after Mermaid's async rendering loop completes.
- The Ctrl+F handler preserves Ctrl+O, Ctrl+R, and Ctrl+0.

---

### Task 1: Main-process native-search IPC

**Files:**
- Modify: `electron/src/main-handlers.js`
- Create: `electron/tests/search-ipc.test.js`

**Interfaces:**
- Consumes: `getWindow(): BrowserWindow | null`.
- Produces: IPC handlers `viewer:find-in-page` and `viewer:stop-find-in-page`.

- [ ] **Step 1: Write the failing IPC test**

```js
test('find IPC starts a case-insensitive Chromium search', async () => {
  await handlers['viewer:find-in-page']({}, { text: 'Mermaid', forward: false, findNext: true });
  assert.deepEqual(calls, [['Mermaid', { forward: false, findNext: true, matchCase: false }]]);
});
```

Also test blank input clears selection, forward defaults to true, and a missing window is safe.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd electron; node --test tests/search-ipc.test.js`

Expected: FAIL because the find handlers are absent.

- [ ] **Step 3: Implement the IPC handlers in `electron/src/main-handlers.js`**

Trim `payload.text`. Non-empty input calls `getWindow()?.webContents.findInPage(text, { forward: payload.forward !== false, findNext: payload.findNext === true, matchCase: false })`; blank input and the dedicated stop handler call `stopFindInPage('clearSelection')`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd electron; node --test tests/search-ipc.test.js`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add electron/src/main-handlers.js electron/tests/search-ipc.test.js
git commit -m "Add native search IPC handlers"
```

### Task 2: Expose find APIs and result events through the preload whitelist

**Files:**
- Modify: `electron/preload.js`
- Modify: `electron/tests/preload-api.test.js`

**Interfaces:**
- Consumes: `viewer:find-in-page`, `viewer:stop-find-in-page`, `viewer:find-result`.
- Produces: `window.viewer.findInPage(payload)`, `stopFindInPage()`, and `onFindResult(callback)`.

- [ ] **Step 1: Write the failing preload test**

Assert that the exact whitelist includes the three new methods; verify `findInPage({ text: 'diagram', forward: true, findNext: true })` invokes its designated channel and that the event subscription cleanup removes exactly its listener.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd electron; node --test tests/preload-api.test.js`

Expected: FAIL because the methods are absent.

- [ ] **Step 3: Implement the bridge**

Add the two invoke methods and an `onFindResult` wrapper that passes only the result object and returns an unsubscribe callback, matching `onFileChanged`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd electron; node --test tests/preload-api.test.js`

Expected: PASS, and no extra API is exposed.

- [ ] **Step 5: Commit**

```powershell
git add electron/preload.js electron/tests/preload-api.test.js
git commit -m "Expose native search bridge"
```

### Task 3: Forward final Chromium result updates

**Files:**
- Modify: `electron/main.js`
- Modify: `electron/tests/renderer-contract.test.js`

**Interfaces:**
- Consumes: `webContents` event `found-in-page` carrying `requestId`, `activeMatchOrdinal`, `matches`, and `finalUpdate`.
- Produces: `viewer:find-result` renderer event.

- [ ] **Step 1: Write the failing contract assertions**

Add source-level assertions for a `found-in-page` listener, final-update filtering, and `send('viewer:find-result', result)`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd electron; node --test tests/renderer-contract.test.js`

Expected: FAIL because forwarding is absent.

- [ ] **Step 3: Implement forwarding in `electron/main.js`**

During window creation, forward only final `found-in-page` results while the window remains valid.

- [ ] **Step 4: Run the test to verify main-process assertions pass**

Run: `cd electron; node --test tests/renderer-contract.test.js`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add electron/main.js electron/tests/renderer-contract.test.js
git commit -m "Forward native find results"
```

### Task 4: Add the find bar and restore search after redraw

**Files:**
- Modify: `electron/renderer/index.html`
- Modify: `electron/tests/renderer-contract.test.js`

**Interfaces:**
- Consumes: the Task 2 bridge and Task 3 result event.
- Produces: `findInput`, previous/next/close controls, `openFindBar()`, `closeFindBar()`, `requestFind(forward, findNext)`, and `restoreFindAfterRender()`.

- [ ] **Step 1: Write the failing renderer contracts**

Assert the find-bar input ID, bridge calls, `window.viewer.onFindResult` subscription, `Ctrl+F` mapping to `openFindBar()`, and a `restoreFindAfterRender()` call after the Mermaid render loop.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd electron; node --test tests/renderer-contract.test.js`

Expected: FAIL because find UI and interactions do not exist.

- [ ] **Step 3: Implement the accessible toolbar**

Place a hidden, compact find bar under the top bar with labeled input, previous/next buttons, live match status, and close control. Add matching light/dark CSS. Native Chromium, not DOM replacement, supplies highlights.

- [ ] **Step 4: Implement query state and input behavior**

On text changes, start a new search with `findNext: true`; previous/next retain it with `findNext: false` and direction. Store the newest request ID, ignore stale results, and render `current/total` or “未找到”. Bind Ctrl+F, Enter, Shift+Enter, and Escape without changing existing Ctrl shortcuts.

- [ ] **Step 5: Restore after document rendering**

Call `restoreFindAfterRender()` after Mermaid rendering and `bindPanZoomHandlers()`. Reissue only a non-whitespace query while the bar is open.

- [ ] **Step 6: Run focused verification**

Run: `cd electron; node --test tests/renderer-contract.test.js tests/preload-api.test.js tests/search-ipc.test.js`

Expected: PASS.

- [ ] **Step 7: Manually verify the Windows application**

Run: `cd electron; npm start`

Expected: A common word in a heading, paragraph, and Mermaid label is case-insensitively found. Verify next/previous, no results, Esc, empty query, file hot reload, Ctrl+O, Ctrl+R, and Ctrl+0.

- [ ] **Step 8: Commit**

```powershell
git add electron/renderer/index.html electron/tests/renderer-contract.test.js
git commit -m "Add Windows native find bar"
```

### Task 5: Full verification and handoff

**Files:**
- Modify: none unless verification discovers a defect.

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: a verified Windows Electron find experience.

- [ ] **Step 1: Run all Electron tests**

Run: `cd electron; npm test`

Expected: PASS with all existing and new Node tests green.

- [ ] **Step 2: Record manual verification**

Repeat Task 4’s scenario, specifically recording whether Chromium visibly highlights a rendered Mermaid SVG label in the shipped Electron version.

- [ ] **Step 3: Commit any verification-only fix**

```powershell
git add electron
git commit -m "Fix native search verification findings"
```

