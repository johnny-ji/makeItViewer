# Electron Windows Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Windows Python/pywebview host with an Electron desktop application that reliably opens, watches, renders, and exports Markdown files.

**Architecture:** Electron's main process owns native dialogs, file access, watching, clipboard, and printing. A context-isolated preload script exposes a minimal `window.viewer` contract to the existing HTML renderer, which retains its Marked and Mermaid rendering responsibilities.

**Tech Stack:** Node.js, Electron, Electron Builder, Node built-in test runner, Marked, Mermaid.

**Spec:** `docs/superpowers/specs/2026-10-13-electron-windows-migration-design.md`

## Global Constraints

- Target Windows 10/11 and package both a portable EXE and NSIS installer.
- Keep `contextIsolation: true` and `nodeIntegration: false`.
- Expose only fixed, allowlisted APIs through `contextBridge`.
- Support Markdown/text file opening, drag-and-drop, UTF-8/GB18030/Big5 reading, live reload, Mermaid, PNG/SVG export, image copy, and PDF printing.
- Retain the Python implementation unchanged until the Electron package passes acceptance checks.

## Review Focus

- Canceling a native file dialog must leave the current document intact.
- A rapid second open request must not create a second active dialog.
- Non-UTF-8 Chinese Markdown must render legibly.
- File watch events produced by atomic saves must refresh the current document once the replacement is readable.
- Renderer-supplied export names and binary data must not permit arbitrary filesystem writes.

---

## File Structure

- `electron/package.json`: scripts, Electron runtime, builder configuration.
- `electron/main.js`: BrowserWindow startup, IPC registration, native menu and renderer events.
- `electron/preload.js`: allowlisted `window.viewer` bridge.
- `electron/src/file-service.js`: encoding-aware read, watcher lifecycle, safe file-name helpers.
- `electron/src/main-handlers.js`: injected dialog and Electron service handlers.
- `electron/renderer/index.html`: migrated existing viewer UI.
- `electron/renderer/vendor/`: offline Marked and Mermaid assets copied from the Windows viewer.
- `electron/tests/*.test.js`: Node unit and renderer-contract tests.

### Task 1: Electron scaffold and secure preload bridge

**Files:**
- Create: `electron/package.json`
- Create: `electron/main.js`
- Create: `electron/preload.js`
- Create: `electron/tests/preload-api.test.js`

**Interfaces:**
- Produces: `window.viewer.openFile()`, `window.viewer.saveSvg(payload)`, `window.viewer.savePng(payload)`, `window.viewer.copyPng(payload)`, `window.viewer.reloadCurrentFile()`, and `window.viewer.onFileChanged(callback)`.

- [ ] **Step 1: Write failing preload API tests**

Use a mocked `contextBridge` and `ipcRenderer`; assert that only the six named methods are exposed and each invokes its fixed IPC channel.

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm test -- --test-name-pattern="preload"`

Expected: FAIL because the Electron scaffold does not exist.

- [ ] **Step 3: Create the Electron scaffold and `preload.js`**

Configure CommonJS scripts `start`, `test`, and `dist`; use `contextBridge.exposeInMainWorld('viewer', api)`. In `main.js`, create a BrowserWindow with the preload script, `contextIsolation: true`, and `nodeIntegration: false`.

- [ ] **Step 4: Run the preload tests to verify they pass**

Run: `npm test -- --test-name-pattern="preload"`

Expected: PASS.

### Task 2: File service and live-reload lifecycle

**Files:**
- Create: `electron/src/file-service.js`
- Create: `electron/tests/file-service.test.js`

**Interfaces:**
- Produces: `readMarkdownFile(filePath) -> { path, filename, content }` and `createFileWatcher(onChange) -> { watch(filePath), close() }`.
- Consumes: Node `fs`, `path`, and `Buffer`.

- [ ] **Step 1: Write failing file-service tests**

Test UTF-8 BOM and GB18030 fallback input, cancellation-safe missing paths, replacing one watched path with another, and debounced change callbacks.

- [ ] **Step 2: Run the file-service tests to verify they fail**

Run: `npm test -- --test-name-pattern="file service"`

Expected: FAIL because `file-service.js` does not exist.

- [ ] **Step 3: Implement `readMarkdownFile` and `createFileWatcher`**

Read buffers and decode in order: UTF-8 BOM/UTF-8, GB18030, Big5; use one active `fs.watch` watcher, debounce notifications, and always close a superseded watcher.

- [ ] **Step 4: Run the file-service tests to verify they pass**

Run: `npm test -- --test-name-pattern="file service"`

Expected: PASS.

### Task 3: Main-process dialog, export, clipboard, and print handlers

**Files:**
- Create: `electron/src/main-handlers.js`
- Create: `electron/tests/main-handlers.test.js`
- Modify: `electron/main.js`

**Interfaces:**
- Consumes: `readMarkdownFile`, `createFileWatcher`, and Electron `dialog`, `clipboard`, `nativeImage`, `ipcMain`.
- Produces: IPC handlers `viewer:open-file`, `viewer:save-svg`, `viewer:save-png`, `viewer:copy-png`, `viewer:reload-file`, and event `viewer:file-changed`.

- [ ] **Step 1: Write failing main-handler tests**

Inject mocked Electron dependencies. Assert a canceled dialog returns `null`, Markdown filters are applied, selected files emit `{ filename, content }`, save handlers honor the user-selected path, and a second open request while a dialog is active returns `null`.

- [ ] **Step 2: Run the main-handler tests to verify they fail**

Run: `npm test -- --test-name-pattern="main handlers"`

Expected: FAIL because the handlers do not exist.

- [ ] **Step 3: Implement and register the main-process handlers**

Use `dialog.showOpenDialog(browserWindow, options)` after Electron is ready. Validate payload shape and generated export filename; route watcher notifications to `webContents.send('viewer:file-changed', document)`; implement print with `webContents.print`.

- [ ] **Step 4: Run the main-handler tests to verify they pass**

Run: `npm test -- --test-name-pattern="main handlers"`

Expected: PASS.

### Task 4: Migrate the renderer from `pywebview` to `window.viewer`

**Files:**
- Create: `electron/renderer/index.html`
- Create: `electron/renderer/vendor/marked.min.js`
- Create: `electron/renderer/vendor/mermaid.min.js`
- Create: `electron/tests/renderer-contract.test.js`

**Interfaces:**
- Consumes: the six-method `window.viewer` API and `viewer:file-changed` callback.
- Produces: open, drag/drop, reload, Mermaid, SVG/PNG export, clipboard, and print UI behavior.

- [ ] **Step 1: Write failing renderer contract tests**

Read the renderer source and assert it contains no `pywebview`, no startup bridge overlay, uses `window.viewer.openFile`, subscribes to `onFileChanged`, and retains Mermaid configuration with `htmlLabels: false`.

- [ ] **Step 2: Run the renderer contract tests to verify they fail**

Run: `npm test -- --test-name-pattern="renderer"`

Expected: FAIL because the Electron renderer does not exist.

- [ ] **Step 3: Migrate the HTML and offline vendor assets**

Copy the stable viewer UI, replace every Python bridge call with the matching preload method, feed returned content to `updateMarkdown`, preserve drag-and-drop, and remove the pywebview startup overlay and polling code.

- [ ] **Step 4: Run the renderer contract tests to verify they pass**

Run: `npm test -- --test-name-pattern="renderer"`

Expected: PASS.

### Task 5: Electron Builder packaging and end-to-end acceptance

**Files:**
- Modify: `electron/package.json`
- Create: `electron/build.bat`
- Modify: `AGENTS.md`

**Interfaces:**
- Produces: `electron/release/MarkdownViewer-Setup.exe` and `electron/release/MarkdownViewer.exe`.

- [ ] **Step 1: Add a failing package configuration check**

Extend `renderer-contract.test.js` to assert Electron Builder configuration enables `nsis` and `portable` Windows targets and names the application `MarkdownViewer`.

- [ ] **Step 2: Run the check to verify it fails**

Run: `npm test -- --test-name-pattern="package"`

Expected: FAIL because no builder configuration exists.

- [ ] **Step 3: Add builder targets and a non-interactive build script**

Set `build.win.target` to `nsis` and `portable`; configure `build.bat` to run `npm ci` followed by `npm run dist` without a pause prompt. Update the contributor guide with Electron commands.

- [ ] **Step 4: Run automated checks and package**

Run: `npm test` then `npm run dist`

Expected: all tests PASS and both Windows artifacts are created.

- [ ] **Step 5: Perform Windows acceptance checks**

Launch the portable EXE and verify first-click open, canceled dialog, repeated click protection, UTF-8 and GB18030 Markdown, file change reload, Mermaid Chinese flowchart labels, PNG/SVG export, clipboard copy, and Print/PDF.

## Plan Self-Review

- Spec coverage: Tasks 1–4 implement the Electron process boundary, native capability set, retained renderer features, and security model; Task 5 handles both requested Windows artifact types and acceptance.
- Interface consistency: all renderer-to-host calls flow through the six `window.viewer` methods defined in Task 1 and registered in Task 3.
- Review focus: cancellation and duplicate dialogs are tested in Task 3; encoding and watch behavior in Task 2; export validation in Task 3; renderer retention in Task 4.
- Scope: Python sources remain untouched until Task 5 confirms the Electron package, matching the migration safety constraint.
