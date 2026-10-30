#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="MarkdownViewer"
OUTPUT_DIR="${SCRIPT_DIR}/dist"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-Installer.dmg"
ZIP_NAME="${APP_NAME}-macOS.zip"

echo "🔨 1. 正在编译通用架构 (Universal Binary: Apple Silicon M系列 + Intel x86)..."
mkdir -p "${OUTPUT_DIR}/build"
rm -rf "${APP_BUNDLE}"

# 编译 arm64
swiftc -O -target arm64-apple-macosx12.0 \
    -framework Cocoa -framework WebKit \
    "${SCRIPT_DIR}/src/main.swift" \
    -o "${OUTPUT_DIR}/build/binary_arm64"

# 编译 x86_64
swiftc -O -target x86_64-apple-macosx12.0 \
    -framework Cocoa -framework WebKit \
    "${SCRIPT_DIR}/src/main.swift" \
    -o "${OUTPUT_DIR}/build/binary_x86_64"

# 2. 组装 .app 目录
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 合并为 Universal 二进制
lipo -create -output "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    "${OUTPUT_DIR}/build/binary_arm64" \
    "${OUTPUT_DIR}/build/binary_x86_64"

cp "${SCRIPT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/"
cp -R "${SCRIPT_DIR}/resources/"* "${APP_BUNDLE}/Contents/Resources/"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Ad-hoc 代码签名，避免 macOS 签名警告
codesign --force --deep --sign - "${APP_BUNDLE}" > /dev/null 2>&1 || true

echo "📦 2. 正在打包通用的 .zip 压缩包（适合微信/飞书/邮件秒传）..."
rm -f "${OUTPUT_DIR}/${ZIP_NAME}"
(cd "${OUTPUT_DIR}" && ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${ZIP_NAME}")

echo "💿 3. 正在生成标准 macOS .dmg 安装镜像..."
rm -f "${OUTPUT_DIR}/${DMG_NAME}"
DMG_TMP="${OUTPUT_DIR}/dmg_staging"
rm -rf "${DMG_TMP}"
mkdir -p "${DMG_TMP}"
cp -R "${APP_BUNDLE}" "${DMG_TMP}/"
ln -s /Applications "${DMG_TMP}/Applications"

hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TMP}" -ov -format UDZO "${OUTPUT_DIR}/${DMG_NAME}" > /dev/null
rm -rf "${DMG_TMP}" "${OUTPUT_DIR}/build"

echo ""
echo "🎉 打包完成！你可以直接把以下任意文件分享给其他 Mac 用户："
echo "   1. 💿 标准安装镜像 (DMG): ${OUTPUT_DIR}/${DMG_NAME}"
echo "   2. 📦 极速压缩包 (ZIP):   ${OUTPUT_DIR}/${ZIP_NAME}"
ls -lh "${OUTPUT_DIR}/${DMG_NAME}" "${OUTPUT_DIR}/${ZIP_NAME}"
