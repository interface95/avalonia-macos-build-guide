#!/bin/bash

# Avalonia macOS 应用构建脚本
# 使用方法: ./build-macos.sh [应用名称] [项目名称] [Bundle ID] [版本号]

# 配置变量（可以通过命令行参数覆盖）
APP_NAME="${1:-YourApp}"
PROJECT_NAME="${2:-YourAvaloniaApp}"
BUNDLE_ID="${3:-com.yourcompany.yourapp}"
VERSION="${4:-1.0.0}"

DESKTOP_PROJECT="${PROJECT_NAME}.Desktop"

echo "========================================"
echo "Avalonia macOS 应用构建脚本"
echo "========================================"
echo "应用名称: $APP_NAME"
echo "项目名称: $PROJECT_NAME"
echo "Desktop 项目: $DESKTOP_PROJECT"
echo "Bundle ID: $BUNDLE_ID"
echo "版本号: $VERSION"
echo "========================================"

# 检查必要工具
check_tools() {
    echo "检查必要工具..."

    if ! command -v dotnet &> /dev/null; then
        echo "错误: 未找到 dotnet CLI。请安装 .NET SDK。"
        exit 1
    fi

    if ! command -v codesign &> /dev/null; then
        echo "错误: 未找到 codesign。请安装 Xcode Command Line Tools。"
        exit 1
    fi

    if ! command -v hdiutil &> /dev/null; then
        echo "错误: 未找到 hdiutil。"
        exit 1
    fi

    echo "✓ 所有必要工具已安装"
}

# 清理旧文件
cleanup() {
    echo "清理旧文件..."
    rm -rf "${APP_NAME}.app" dmg_contents "${APP_NAME}.dmg"
    echo "✓ 清理完成"
}

# 恢复依赖
restore_dependencies() {
    echo "恢复依赖..."
    if ! dotnet restore; then
        echo "错误: 依赖恢复失败"
        exit 1
    fi
    echo "✓ 依赖恢复完成"
}

# 发布应用
publish_app() {
    echo "发布应用..."

    if [ ! -d "${DESKTOP_PROJECT}" ]; then
        echo "错误: 未找到 Desktop 项目目录: ${DESKTOP_PROJECT}"
        echo "请确认项目结构或修改 PROJECT_NAME 参数"
        exit 1
    fi

    if ! dotnet publish "${DESKTOP_PROJECT}/${DESKTOP_PROJECT}.csproj" \
        -r osx-arm64 \
        -c Release \
        -p:PublishAot=true; then
        echo "错误: 应用发布失败"
        exit 1
    fi
    echo "✓ 应用发布完成"
}

# 创建 .app 包结构
create_app_bundle() {
    echo "创建 .app 包..."

    mkdir -p "${APP_NAME}.app/Contents/MacOS"
    mkdir -p "${APP_NAME}.app/Contents/Resources"

    echo "✓ .app 包结构创建完成"
}

# 复制必要文件
copy_files() {
    echo "复制必要文件..."

    PUBLISH_DIR="${DESKTOP_PROJECT}/bin/Release/net9.0/osx-arm64/publish"

    if [ ! -d "$PUBLISH_DIR" ]; then
        echo "错误: 发布目录不存在: $PUBLISH_DIR"
        exit 1
    fi

    # 检查并复制主执行文件
    if [ ! -f "${PUBLISH_DIR}/${DESKTOP_PROJECT}" ]; then
        echo "错误: 主执行文件不存在: ${PUBLISH_DIR}/${DESKTOP_PROJECT}"
        exit 1
    fi
    cp "${PUBLISH_DIR}/${DESKTOP_PROJECT}" "${APP_NAME}.app/Contents/MacOS/"

    # 复制必要的动态库
    required_libs=(
        "libAvaloniaNative.dylib"
        "libHarfBuzzSharp.dylib"
        "libSkiaSharp.dylib"
    )

    for lib in "${required_libs[@]}"; do
        if [ ! -f "${PUBLISH_DIR}/${lib}" ]; then
            echo "警告: 未找到动态库: ${lib}"
        else
            cp "${PUBLISH_DIR}/${lib}" "${APP_NAME}.app/Contents/MacOS/"
            echo "✓ 复制 ${lib}"
        fi
    done

    echo "✓ 文件复制完成"
}

# 创建 Info.plist
create_info_plist() {
    echo "创建 Info.plist..."

    cat > "${APP_NAME}.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${DESKTOP_PROJECT}</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © $(date +%Y). All rights reserved.</string>
</dict>
</plist>
EOF

    echo "✓ Info.plist 创建完成"
}

# 设置权限和签名
sign_app() {
    echo "设置权限和签名..."

    # 设置可执行权限
    chmod +x "${APP_NAME}.app/Contents/MacOS/${DESKTOP_PROJECT}"

    # 使用临时签名
    if ! codesign --force --deep --sign - "${APP_NAME}.app"; then
        echo "错误: 应用签名失败"
        exit 1
    fi

    # 验证签名
    if ! codesign --verify --verbose "${APP_NAME}.app"; then
        echo "错误: 签名验证失败"
        exit 1
    fi

    echo "✓ 签名完成"
}

# 创建 DMG
create_dmg() {
    echo "创建 DMG..."

    mkdir -p dmg_contents
    cp -R "${APP_NAME}.app" dmg_contents/
    ln -s /Applications dmg_contents/Applications

    if ! hdiutil create -volname "${APP_NAME}" \
        -srcfolder dmg_contents \
        -ov -format UDZO \
        "${APP_NAME}.dmg"; then
        echo "错误: DMG 创建失败"
        exit 1
    fi

    rm -rf dmg_contents
    echo "✓ DMG 创建完成"
}

# 显示结果
show_results() {
    echo "========================================"
    echo "构建完成！"
    echo "========================================"
    echo "生成的文件："

    if [ -d "${APP_NAME}.app" ]; then
        app_size=$(du -sh "${APP_NAME}.app" | cut -f1)
        echo "✓ ${APP_NAME}.app (应用包, ${app_size})"
    fi

    if [ -f "${APP_NAME}.dmg" ]; then
        dmg_size=$(du -sh "${APP_NAME}.dmg" | cut -f1)
        echo "✓ ${APP_NAME}.dmg (安装包, ${dmg_size})"
    fi

    echo ""
    echo "测试应用:"
    echo "  open ${APP_NAME}.app"
    echo ""
    echo "打开 DMG:"
    echo "  open ${APP_NAME}.dmg"
    echo "========================================"
}

# 显示帮助信息
show_help() {
    echo "使用方法: $0 [应用名称] [项目名称] [Bundle ID] [版本号]"
    echo ""
    echo "参数说明:"
    echo "  应用名称    生成的 .app 和 .dmg 文件名 (默认: YourApp)"
    echo "  项目名称    Avalonia 项目名称 (默认: YourAvaloniaApp)"
    echo "  Bundle ID   应用的 Bundle Identifier (默认: com.yourcompany.yourapp)"
    echo "  版本号      应用版本号 (默认: 1.0.0)"
    echo ""
    echo "示例:"
    echo "  $0 MyApp MyAvaloniaApp com.mycompany.myapp 1.2.3"
    echo ""
    echo "注意: 项目名称将用于查找 [项目名称].Desktop 目录"
}

# 主函数
main() {
    # 检查是否需要显示帮助
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    # 执行构建流程
    check_tools
    cleanup
    restore_dependencies
    publish_app
    create_app_bundle
    copy_files
    create_info_plist
    sign_app
    create_dmg
    show_results
}

# 错误处理
set -e
trap 'echo "错误: 构建过程中发生异常，请检查上面的错误信息。"' ERR

# 执行主函数
main "$@"