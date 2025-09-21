# Avalonia macOS PKG 安装包构建指南

本指南详细介绍如何将 Avalonia 应用程序打包为 macOS `.pkg` 安装包格式，提供类似 MAUI 的一键打包体验。

## 目录

- [概述](#概述)
- [前置要求](#前置要求)
- [快速开始](#快速开始)
- [详细步骤](#详细步骤)
- [脚本配置](#脚本配置)
- [项目配置](#项目配置)
- [自动化脚本](#自动化脚本)
- [GitHub Actions 集成](#github-actions-集成)
- [故障排除](#故障排除)
- [进阶配置](#进阶配置)

## 概述

`.pkg` 格式是 macOS 的标准安装包格式，具有以下优势：

- ✅ **标准格式**: macOS 原生支持，用户熟悉
- ✅ **自动安装**: 双击即可安装到 `/Applications` 目录
- ✅ **卸载简单**: 通过 Finder 删除应用即可
- ✅ **分发友好**: 适合企业内部分发和在线下载
- ✅ **安装器集成**: 可通过命令行工具管理

## 前置要求

### 系统要求

- macOS 10.15 或更高版本
- Xcode Command Line Tools
- .NET 9.0 SDK 或更高版本

### 安装必要工具

```bash
# 安装 Xcode Command Line Tools
xcode-select --install

# 验证工具安装
dotnet --version
codesign --version
pkgbuild --version
```

## 快速开始

### 1. 配置项目

在你的 Avalonia Desktop 项目文件 (`.csproj`) 中添加 PKG 打包配置：

```xml
<PropertyGroup Condition="'$(RuntimeIdentifier)' == 'osx-arm64' OR '$(RuntimeIdentifier)' == 'osx-x64'">
    <CreatePackage>true</CreatePackage>
    <EnablePackageSigning>false</EnablePackageSigning>
    <PackageSigningKey></PackageSigningKey>
    <PackageId>com.yourcompany.yourapp</PackageId>
    <Title>YourAppName</Title>
    <PackageVersion>1.0.0</PackageVersion>
    <Authors>Your Name</Authors>
    <Description>Your App Description</Description>
</PropertyGroup>
```

### 2. 下载打包脚本

将 [`build-pkg.sh`](#自动化脚本) 脚本放到项目根目录并设置执行权限：

```bash
chmod +x build-pkg.sh
```

### 3. 运行打包

```bash
./build-pkg.sh
```

构建完成后，你将得到：
- `YourApp.app` - macOS 应用包
- `YourApp.pkg` - PKG 安装包

## 详细步骤

### 步骤 1: 发布应用

```bash
dotnet publish YourApp.Desktop -r osx-arm64 -c Release -p:PublishAot=true
```

**参数说明：**
- `-r osx-arm64`: 针对 Apple Silicon 处理器
- `-c Release`: 发布模式
- `-p:PublishAot=true`: 启用 AOT 原生编译

### 步骤 2: 创建 .app 包结构

```bash
mkdir -p "YourApp.app/Contents/MacOS"
mkdir -p "YourApp.app/Contents/Resources"
```

### 步骤 3: 复制应用文件

```bash
PUBLISH_DIR="YourApp.Desktop/bin/Release/net9.0/osx-arm64/publish"

# 复制主执行文件
cp "$PUBLISH_DIR/YourApp.Desktop" "YourApp.app/Contents/MacOS/"

# 复制必要的动态库
cp "$PUBLISH_DIR/libAvaloniaNative.dylib" "YourApp.app/Contents/MacOS/"
cp "$PUBLISH_DIR/libHarfBuzzSharp.dylib" "YourApp.app/Contents/MacOS/"
cp "$PUBLISH_DIR/libSkiaSharp.dylib" "YourApp.app/Contents/MacOS/"
```

### 步骤 4: 创建 Info.plist

```bash
cat > "YourApp.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>YourApp.Desktop</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourcompany.yourapp</string>
    <key>CFBundleName</key>
    <string>YourApp</string>
    <key>CFBundleDisplayName</key>
    <string>YourApp</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF
```

### 步骤 5: 代码签名

```bash
# 设置执行权限
chmod +x "YourApp.app/Contents/MacOS/YourApp.Desktop"

# 签名动态库
codesign --force --deep --sign - "YourApp.app/Contents/MacOS/YourApp.Desktop"
codesign --force --deep --sign - "YourApp.app/Contents/MacOS"/*.dylib

# 签名整个应用包
codesign --force --deep --sign - "YourApp.app"
```

### 步骤 6: 创建 PKG 包

```bash
pkgbuild --root "YourApp.app" \\
         --identifier "com.yourcompany.yourapp" \\
         --version "1.0.0" \\
         --install-location "/Applications/YourApp.app" \\
         "YourApp.pkg"
```

### 步骤 7: 验证结果

```bash
# 检查 PKG 包信息
installer -pkginfo -pkg YourApp.pkg

# 测试安装（需要管理员权限）
sudo installer -pkg YourApp.pkg -target /

# 卸载
sudo rm -rf /Applications/YourApp.app
```

## 脚本配置

### 自定义变量

在脚本开头修改这些变量以适配你的项目：

```bash
APP_NAME="YourApp"                              # 应用显示名称
BUNDLE_ID="com.yourcompany.yourapp"             # Bundle 标识符
VERSION="1.0.0"                                 # 版本号
PUBLISH_DIR="YourApp.Desktop/bin/Release/net9.0/osx-arm64/publish"
```

### 图标配置

如果你有应用图标 (`.icns` 格式)：

```bash
# 在脚本中添加图标复制
if [ -f "YourApp.icns" ]; then
    cp "YourApp.icns" "${APP_BUNDLE}/Contents/Resources/"
fi
```

并在 `Info.plist` 中添加：

```xml
<key>CFBundleIconFile</key>
<string>YourApp.icns</string>
```

## 项目配置

### .csproj 配置示例

完整的 Desktop 项目配置：

```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <OutputType>WinExe</OutputType>
        <TargetFramework>net9.0</TargetFramework>
        <Nullable>enable</Nullable>
        <BuiltInComInteropSupport>true</BuiltInComInteropSupport>
    </PropertyGroup>

    <PropertyGroup>
        <ApplicationManifest>app.manifest</ApplicationManifest>
    </PropertyGroup>

    <!-- PKG 打包配置 -->
    <PropertyGroup Condition="'$(RuntimeIdentifier)' == 'osx-arm64' OR '$(RuntimeIdentifier)' == 'osx-x64'">
        <CreatePackage>true</CreatePackage>
        <EnablePackageSigning>false</EnablePackageSigning>
        <PackageSigningKey></PackageSigningKey>
        <PackageId>com.example.avaloniaapplication1</PackageId>
        <Title>AvaloniaApplication1</Title>
        <PackageVersion>1.0.0</PackageVersion>
        <Authors>Your Name</Authors>
        <Description>AvaloniaApplication1 macOS Application</Description>
    </PropertyGroup>

    <ItemGroup>
        <PackageReference Include="Avalonia.Desktop"/>
        <PackageReference Include="Avalonia.Diagnostics">
            <IncludeAssets Condition="'$(Configuration)' != 'Debug'">None</IncludeAssets>
            <PrivateAssets Condition="'$(Configuration)' != 'Debug'">All</PrivateAssets>
        </PackageReference>
    </ItemGroup>

    <ItemGroup>
        <ProjectReference Include="..\\YourApp\\YourApp.csproj"/>
    </ItemGroup>
</Project>
```

## 自动化脚本

创建 `build-pkg.sh` 脚本：

```bash
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
pkgbuild --root "${APP_BUNDLE}" \\
         --identifier "${BUNDLE_ID}" \\
         --version "${VERSION}" \\
         --install-location "/Applications/${APP_NAME}.app" \\
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
```

使用脚本：

```bash
# 设置执行权限
chmod +x build-pkg.sh

# 运行构建
./build-pkg.sh
```

## GitHub Actions 集成

创建 `.github/workflows/build-pkg.yml`：

```yaml
name: Build macOS PKG

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  build-pkg:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v4

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '9.0.x'
        include-prerelease: true

    - name: Make build script executable
      run: chmod +x build-pkg.sh

    - name: Build PKG package
      run: ./build-pkg.sh

    - name: Upload PKG artifact
      uses: actions/upload-artifact@v4
      with:
        name: AvaloniaApplication1-macOS-PKG
        path: AvaloniaApplication1.pkg
        retention-days: 30

    - name: Create GitHub Release
      uses: softprops/action-gh-release@v1
      with:
        files: AvaloniaApplication1.pkg
        name: Release ${{ github.ref_name }}
        draft: false
        prerelease: false
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

触发构建：

```bash
# 创建并推送版本标签
git tag v1.0.0
git push origin v1.0.0
```

## 故障排除

### 常见问题

1. **权限被拒绝错误**
   ```bash
   chmod +x YourApp.app/Contents/MacOS/YourExecutable
   ```

2. **签名失败**
   ```bash
   # 清除现有签名并重新签名
   codesign --remove-signature YourApp.app
   codesign --force --deep --sign - YourApp.app
   ```

3. **PKG 创建失败**
   ```bash
   # 检查应用包结构
   find YourApp.app -type f

   # 验证 Bundle ID 格式
   echo "com.yourcompany.yourapp" | grep -E '^[a-zA-Z0-9.-]+$'
   ```

4. **应用无法启动**
   - 检查 `Info.plist` 中的 `CFBundleExecutable` 与实际文件名是否匹配
   - 确保所有必要的 `.dylib` 文件都已复制
   - 验证执行权限是否正确设置

### 调试技巧

1. **验证 PKG 包内容**
   ```bash
   pkgutil --payload-files YourApp.pkg
   pkgutil --expand YourApp.pkg expanded_pkg
   ```

2. **检查应用依赖**
   ```bash
   otool -L YourApp.app/Contents/MacOS/YourExecutable
   ```

3. **测试应用启动**
   ```bash
   # 从命令行启动查看错误信息
   ./YourApp.app/Contents/MacOS/YourExecutable
   ```

4. **验证签名**
   ```bash
   codesign --verify --verbose YourApp.app
   spctl --assess --verbose YourApp.app
   ```

## 进阶配置

### 生产环境代码签名

对于 App Store 或公开分发：

```bash
# 使用开发者证书签名
codesign --force --deep --sign "Developer ID Application: Your Name" YourApp.app

# 公证应用（macOS 10.15+）
xcrun notarytool submit YourApp.pkg \\
    --apple-id your-apple-id@example.com \\
    --password your-app-specific-password \\
    --team-id YOUR_TEAM_ID \\
    --wait
```

### 支持多架构

创建通用二进制文件：

```bash
# 发布 Intel 版本
dotnet publish -r osx-x64 -c Release -p:PublishAot=true

# 发布 ARM64 版本
dotnet publish -r osx-arm64 -c Release -p:PublishAot=true

# 使用 lipo 合并
lipo -create \\
    path/to/osx-x64/YourApp \\
    path/to/osx-arm64/YourApp \\
    -output YourApp.app/Contents/MacOS/YourApp
```

### 自定义安装脚本

添加预安装和后安装脚本：

```bash
# 创建脚本目录
mkdir -p scripts

# 创建预安装脚本
cat > scripts/preinstall << 'EOF'
#!/bin/bash
echo "准备安装应用..."
EOF

# 创建后安装脚本
cat > scripts/postinstall << 'EOF'
#!/bin/bash
echo "应用安装完成！"
EOF

# 设置执行权限
chmod +x scripts/*

# 使用脚本构建 PKG
pkgbuild --root "YourApp.app" \\
         --scripts scripts \\
         --identifier "com.yourcompany.yourapp" \\
         --version "1.0.0" \\
         --install-location "/Applications/YourApp.app" \\
         "YourApp.pkg"
```

## 与 MAUI 对比

| 特性 | Avalonia PKG | MAUI |
|------|-------------|------|
| 一键打包 | ✅ | ✅ |
| 原生性能 | ✅ (AOT) | ✅ |
| 包大小 | 小 (~16MB) | 中等 |
| 跨平台支持 | 优秀 | 优秀 |
| 生态系统 | 新兴 | 成熟 |
| 学习曲线 | 平缓 | 中等 |

---

**注意：** 本指南基于 .NET 9.0 和 Avalonia 11.x 版本。对于不同版本，可能需要调整相应的配置。

## 许可证

本文档采用 MIT 许可证。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进本指南。