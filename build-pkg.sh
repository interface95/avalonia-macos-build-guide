#!/bin/bash

# Avalonia Application PKG Builder
# 此脚本将 Avalonia.Desktop 应用打包为 macOS .pkg 安装包

set -e

APP_NAME="AvaloniaApplication1"
BUNDLE_ID="com.example.avaloniaapplication1"
VERSION="1.0.0"
PUBLISH_DIR="AvaloniaApplication1.Desktop/bin/Release/net9.0/osx-arm64/publish"
APP_BUNDLE="${APP_NAME}.app"
PKG_NAME="${APP_NAME}.pkg"

echo "🚀 开始构建 ${APP_NAME} .pkg 包..."

# 1. 清理旧文件
echo "📁 清理旧文件..."
rm -rf "${APP_BUNDLE}"
rm -f "${PKG_NAME}"

# 2. 发布应用
echo "🔨 发布应用..."
dotnet publish AvaloniaApplication1.Desktop -r osx-arm64 -c Release -p:PublishAot=true

# 3. 检查发布是否成功
if [ ! -d "${PUBLISH_DIR}" ]; then
    echo "❌ 发布失败: ${PUBLISH_DIR} 目录不存在"
    exit 1
fi

# 4. 创建 .app 包结构
echo "📦 创建 .app 包结构..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 5. 复制文件
echo "📄 复制应用文件..."
cp "${PUBLISH_DIR}/AvaloniaApplication1.Desktop" "${APP_BUNDLE}/Contents/MacOS/"
cp "${PUBLISH_DIR}"/lib*.dylib "${APP_BUNDLE}/Contents/MacOS/" 2>/dev/null || true

# 6. 复制图标（如果存在）
if [ -f "AvaloniaApplication1.icns" ]; then
    echo "🎨 复制应用图标..."
    cp "AvaloniaApplication1.icns" "${APP_BUNDLE}/Contents/Resources/"
fi

# 7. 设置执行权限
echo "🔐 设置执行权限..."
chmod +x "${APP_BUNDLE}/Contents/MacOS/AvaloniaApplication1.Desktop"

# 8. 创建 Info.plist
echo "📋 创建 Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AvaloniaApplication1.Desktop</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>$(if [ -f "AvaloniaApplication1.icns" ]; then echo "
    <key>CFBundleIconFile</key>
    <string>AvaloniaApplication1.icns</string>"; fi)
</dict>
</plist>
EOF

# 9. 代码签名
echo "✍️  代码签名..."
codesign --force --deep --sign - "${APP_BUNDLE}/Contents/MacOS/AvaloniaApplication1.Desktop"
codesign --force --deep --sign - "${APP_BUNDLE}/Contents/MacOS"/lib*.dylib 2>/dev/null || true
codesign --force --deep --sign - "${APP_BUNDLE}"

# 10. 创建 .pkg 包
echo "📦 创建 .pkg 包..."
pkgbuild --root "${APP_BUNDLE}" \
         --identifier "${BUNDLE_ID}" \
         --version "${VERSION}" \
         --install-location "/Applications/${APP_NAME}.app" \
         "${PKG_NAME}"

# 11. 验证结果
if [ -f "${PKG_NAME}" ]; then
    echo "✅ 成功创建 ${PKG_NAME}"
    echo "📏 包大小: $(du -h "${PKG_NAME}" | cut -f1)"
    echo "🎯 安装位置: /Applications/${APP_NAME}.app"
    echo ""
    echo "🔍 要测试安装，请运行:"
    echo "   sudo installer -pkg ${PKG_NAME} -target /"
    echo ""
    echo "🗑️  要卸载，请运行:"
    echo "   sudo rm -rf /Applications/${APP_NAME}.app"
else
    echo "❌ 创建 .pkg 包失败"
    exit 1
fi