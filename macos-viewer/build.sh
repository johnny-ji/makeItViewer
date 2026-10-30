#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="MarkdownViewer"
OUTPUT_DIR="${SCRIPT_DIR}/dist"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

echo "🔨 开始构建 macOS 原生 App: ${APP_NAME}..."

mkdir -p "${OUTPUT_DIR}"
rm -rf "${APP_BUNDLE}"

# 1. 创建 .app 目录骨架
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 2. 编译 Swift 主程序
echo "⚡ 正在编译 Swift 源代码..."
swiftc -O \
    -framework Cocoa \
    -framework WebKit \
    "${SCRIPT_DIR}/src/main.swift" \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# 3. 拷贝 Info.plist 与离线资源
echo "📦 正在打包离线资源与配置文件..."
cp "${SCRIPT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/"
cp -R "${SCRIPT_DIR}/resources/"* "${APP_BUNDLE}/Contents/Resources/"

# 4. 设置执行权限
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "✅ 构建成功！"
echo "📍 App 路径: ${APP_BUNDLE}"
echo ""
echo "💡 提示："
echo "   - 直接双击运行: open \"${APP_BUNDLE}\""
echo "   - 打开指定文件: open -a \"${APP_BUNDLE}\" path/to/file.md"
echo "   - 拷贝到系统应用: cp -R \"${APP_BUNDLE}\" /Applications/"
