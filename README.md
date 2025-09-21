# Avalonia macOS 应用打包指南

本指南详细介绍如何将 Avalonia 应用程序打包为 macOS 原生应用（.app）、DMG 安装包和 PKG 安装包。

## 📦 打包格式

本指南支持三种 macOS 应用打包格式：

| 格式 | 适用场景 | 特点 |
|------|----------|------|
| **[.app 包](#构建步骤)** | 开发调试 | 原生应用格式，可直接运行 |
| **[DMG 安装包](#创建-dmg-安装包)** | 用户分发 | 磁盘镜像，拖拽安装体验 |
| **[PKG 安装包](PKG-GUIDE.md)** | 企业分发 | 标准安装包，一键安装到 Applications |

## 目录

- [前置要求](#前置要求)
- [项目结构](#项目结构)
- [构建步骤](#构建步骤)
- [PKG 打包指南](#pkg-打包指南)
- [自动化脚本](#自动化脚本)
- [GitHub Actions 自动化](#github-actions-自动化)
- [故障排除](#故障排除)

## 前置要求

### 系统要求
- macOS 10.15 或更高版本
- Xcode Command Line Tools
- .NET 9.0 SDK 或更高版本

### 安装依赖

```bash
# 安装 Xcode Command Line Tools
xcode-select --install

# 验证 .NET 安装
dotnet --version

# 验证 codesign 可用性
codesign --version
```

## 项目结构

典型的 Avalonia 项目结构：

```
YourAvaloniaApp/
├── YourAvaloniaApp/                 # 核心库项目
├── YourAvaloniaApp.Desktop/         # 桌面平台项目
├── YourAvaloniaApp.sln
└── Directory.Packages.props
```

确保您的 Desktop 项目包含以下配置：

```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <OutputType>WinExe</OutputType>
        <TargetFramework>net9.0</TargetFramework>
        <Nullable>enable</Nullable>
        <BuiltInComInteropSupport>true</BuiltInComInteropSupport>
    </PropertyGroup>

    <ItemGroup>
        <PackageReference Include="Avalonia.Desktop"/>
        <PackageReference Include="Avalonia.Diagnostics">
            <IncludeAssets Condition="'$(Configuration)' != 'Debug'">None</IncludeAssets>
            <PrivateAssets Condition="'$(Configuration)' != 'Debug'">All</PrivateAssets>
        </PackageReference>
    </ItemGroup>

    <ItemGroup>
        <ProjectReference Include="..\YourAvaloniaApp\YourAvaloniaApp.csproj"/>
    </ItemGroup>
</Project>
```

## 构建步骤

### 1. 恢复依赖并发布应用

```bash
# 恢复 NuGet 包
dotnet restore

# 发布 macOS ARM64 版本（推荐使用 AOT 编译）
dotnet publish YourAvaloniaApp.Desktop/YourAvaloniaApp.Desktop.csproj \
    -r osx-arm64 \
    -c Release \
    -p:PublishAot=true
```

**注意：**
- 使用 `osx-arm64` 适用于 Apple Silicon (M1/M2/M3) Mac
- 使用 `osx-x64` 适用于 Intel Mac
- AOT 编译可以显著减少应用大小和提高启动速度

### 2. 创建 .app 包结构

```bash
# 清理旧的构建文件
rm -rf YourApp.app

# 创建 .app 包目录结构
mkdir -p "YourApp.app/Contents/MacOS"
mkdir -p "YourApp.app/Contents/Resources"
```

### 3. 复制必要文件

对于精简版本，只需要复制这四个核心文件：

```bash
# 复制主执行文件
cp YourAvaloniaApp.Desktop/bin/Release/net9.0/osx-arm64/publish/YourAvaloniaApp.Desktop \
   YourApp.app/Contents/MacOS/

# 复制必要的动态库
cp YourAvaloniaApp.Desktop/bin/Release/net9.0/osx-arm64/publish/libAvaloniaNative.dylib \
   YourApp.app/Contents/MacOS/

cp YourAvaloniaApp.Desktop/bin/Release/net9.0/osx-arm64/publish/libHarfBuzzSharp.dylib \
   YourApp.app/Contents/MacOS/

cp YourAvaloniaApp.Desktop/bin/Release/net9.0/osx-arm64/publish/libSkiaSharp.dylib \
   YourApp.app/Contents/MacOS/
```

### 4. 创建 Info.plist

```bash
cat > YourApp.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>YourAvaloniaApp.Desktop</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourcompany.yourapp</string>
    <key>CFBundleName</key>
    <string>YourApp</string>
    <key>CFBundleDisplayName</key>
    <string>Your App Display Name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Your Company. All rights reserved.</string>
</dict>
</plist>
EOF
```

### 5. 设置权限和签名

```bash
# 设置可执行权限
chmod +x YourApp.app/Contents/MacOS/YourAvaloniaApp.Desktop

# 使用临时签名（适用于本地开发）
codesign --force --deep --sign - YourApp.app

# 验证签名
codesign --verify --verbose YourApp.app
```

### 6. 创建 DMG 安装包

```bash
# 创建 DMG 内容目录
mkdir -p dmg_contents
cp -R YourApp.app dmg_contents/

# 创建 Applications 文件夹的符号链接
ln -s /Applications dmg_contents/Applications

# 创建 DMG 文件
hdiutil create -volname "Your App Name" \
    -srcfolder dmg_contents \
    -ov -format UDZO \
    YourApp.dmg

# 清理临时文件
rm -rf dmg_contents
```

## 自动化脚本

创建一个自动化构建脚本 `build-macos.sh`：

```bash
#!/bin/bash

# 配置变量
APP_NAME="YourApp"
PROJECT_NAME="YourAvaloniaApp"
DESKTOP_PROJECT="${PROJECT_NAME}.Desktop"
BUNDLE_ID="com.yourcompany.yourapp"
VERSION="1.0.0"

echo "开始构建 macOS 应用..."

# 清理旧文件
echo "清理旧文件..."
rm -rf "${APP_NAME}.app" dmg_contents "${APP_NAME}.dmg"

# 恢复依赖
echo "恢复依赖..."
dotnet restore

# 发布应用
echo "发布应用..."
dotnet publish "${DESKTOP_PROJECT}/${DESKTOP_PROJECT}.csproj" \
    -r osx-arm64 \
    -c Release \
    -p:PublishAot=true

# 创建 .app 包结构
echo "创建 .app 包..."
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# 复制文件
echo "复制必要文件..."
PUBLISH_DIR="${DESKTOP_PROJECT}/bin/Release/net9.0/osx-arm64/publish"
cp "${PUBLISH_DIR}/${DESKTOP_PROJECT}" "${APP_NAME}.app/Contents/MacOS/"
cp "${PUBLISH_DIR}/libAvaloniaNative.dylib" "${APP_NAME}.app/Contents/MacOS/"
cp "${PUBLISH_DIR}/libHarfBuzzSharp.dylib" "${APP_NAME}.app/Contents/MacOS/"
cp "${PUBLISH_DIR}/libSkiaSharp.dylib" "${APP_NAME}.app/Contents/MacOS/"

# 创建 Info.plist
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
    <string>Copyright © 2024. All rights reserved.</string>
</dict>
</plist>
EOF

# 设置权限和签名
echo "设置权限和签名..."
chmod +x "${APP_NAME}.app/Contents/MacOS/${DESKTOP_PROJECT}"
codesign --force --deep --sign - "${APP_NAME}.app"
codesign --verify --verbose "${APP_NAME}.app"

# 创建 DMG
echo "创建 DMG..."
mkdir -p dmg_contents
cp -R "${APP_NAME}.app" dmg_contents/
ln -s /Applications dmg_contents/Applications
hdiutil create -volname "${APP_NAME}" -srcfolder dmg_contents -ov -format UDZO "${APP_NAME}.dmg"
rm -rf dmg_contents

echo "构建完成！"
echo "生成的文件："
echo "  - ${APP_NAME}.app (应用包)"
echo "  - ${APP_NAME}.dmg (安装包)"
```

使用脚本：

```bash
# 设置执行权限
chmod +x build-macos.sh

# 运行构建
./build-macos.sh
```

## PKG 打包指南

### 🚀 快速开始 PKG 打包

除了 DMG 格式，我们还提供了 **PKG 打包方案**，这是 macOS 的标准安装包格式，适合企业分发和自动化部署。

#### 主要优势

- ✅ **一键安装**: 双击即可自动安装到 `/Applications` 目录
- ✅ **MAUI 体验**: 提供类似 MAUI 的一键打包流程
- ✅ **企业友好**: 支持命令行安装和卸载
- ✅ **标准格式**: macOS 原生支持的安装包格式

#### 快速使用

1. **下载 PKG 打包脚本**：
   ```bash
   curl -O https://raw.githubusercontent.com/interface95/avalonia-macos-build-guide/main/build-pkg.sh
   chmod +x build-pkg.sh
   ```

2. **配置项目**（在 Desktop 项目的 `.csproj` 中添加）：
   ```xml
   <PropertyGroup Condition="'$(RuntimeIdentifier)' == 'osx-arm64' OR '$(RuntimeIdentifier)' == 'osx-x64'">
       <CreatePackage>true</CreatePackage>
       <PackageId>com.yourcompany.yourapp</PackageId>
       <Title>YourAppName</Title>
       <PackageVersion>1.0.0</PackageVersion>
   </PropertyGroup>
   ```

3. **一键打包**：
   ```bash
   ./build-pkg.sh
   ```

4. **安装测试**：
   ```bash
   sudo installer -pkg YourApp.pkg -target /
   ```

#### 详细文档

完整的 PKG 打包配置和高级功能请参考：

📖 **[PKG 打包详细指南](PKG-GUIDE.md)**

该文档包含：
- 详细的步骤说明
- 项目配置示例
- GitHub Actions 自动化
- 故障排除和调试技巧
- 生产环境代码签名
- 多架构支持

## GitHub Actions 自动化

创建 `.github/workflows/build-macos.yml` 文件实现自动化构建：

```yaml
name: Build macOS DMG

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  build-macos:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v4

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '9.0.x'
        include-prerelease: true

    - name: Restore dependencies
      run: dotnet restore

    - name: Publish for macOS ARM64 with AOT
      run: dotnet publish YourAvaloniaApp.Desktop/YourAvaloniaApp.Desktop.csproj -r osx-arm64 -c Release -p:PublishAot=true

    - name: Create .app bundle
      run: |
        # Extract version from tag (remove 'v' prefix)
        VERSION=${GITHUB_REF#refs/tags/v}
        echo "Building version: $VERSION"

        # Create app bundle structure
        mkdir -p "YourApp.app/Contents/MacOS"
        mkdir -p "YourApp.app/Contents/Resources"

        # Copy published files to app bundle
        cp YourAvaloniaApp.Desktop/bin/Release/net9.0/osx-arm64/publish/YourAvaloniaApp.Desktop YourApp.app/Contents/MacOS/
        cp YourAvaloniaApp.Desktop/bin/Release/net9.0/osx-arm64/publish/libAvaloniaNative.dylib YourApp.app/Contents/MacOS/
        cp YourAvaloniaApp.Desktop/bin/Release/net9.0/osx-arm64/publish/libHarfBuzzSharp.dylib YourApp.app/Contents/MacOS/
        cp YourAvaloniaApp.Desktop/bin/Release/net9.0/osx-arm64/publish/libSkiaSharp.dylib YourApp.app/Contents/MacOS/

        # Create Info.plist with dynamic version
        cat > YourApp.app/Contents/Info.plist << EOF
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleExecutable</key>
            <string>YourAvaloniaApp.Desktop</string>
            <key>CFBundleIconFile</key>
            <string>icon</string>
            <key>CFBundleIdentifier</key>
            <string>com.yourcompany.yourapp</string>
            <key>CFBundleName</key>
            <string>YourApp</string>
            <key>CFBundleDisplayName</key>
            <string>YourApp</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleVersion</key>
            <string>$VERSION</string>
            <key>CFBundleShortVersionString</key>
            <string>$VERSION</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>LSMinimumSystemVersion</key>
            <string>10.15</string>
            <key>NSHighResolutionCapable</key>
            <true/>
            <key>NSHumanReadableCopyright</key>
            <string>Copyright © 2024. All rights reserved.</string>
        </dict>
        </plist>
        EOF

        # Make executable
        chmod +x YourApp.app/Contents/MacOS/YourAvaloniaApp.Desktop

        # Sign with ad-hoc signature for distribution
        codesign --force --deep --sign - YourApp.app

        # Verify signing
        codesign --verify --verbose YourApp.app

    - name: Create DMG
      run: |
        # Create DMG contents directory
        mkdir -p dmg_contents
        cp -R YourApp.app dmg_contents/

        # Create symbolic link to Applications
        ln -s /Applications dmg_contents/Applications

        # Create DMG
        hdiutil create -volname "YourApp" -srcfolder dmg_contents -ov -format UDZO YourApp.dmg

    - name: Upload DMG artifact
      uses: actions/upload-artifact@v4
      with:
        name: YourApp-macOS-ARM64
        path: YourApp.dmg
        retention-days: 30

    - name: Create GitHub Release
      uses: softprops/action-gh-release@v1
      with:
        files: YourApp.dmg
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
   # 确保设置了正确的执行权限
   chmod +x YourApp.app/Contents/MacOS/YourExecutable
   ```

2. **签名失败**
   ```bash
   # 清除现有签名并重新签名
   codesign --remove-signature YourApp.app
   codesign --force --deep --sign - YourApp.app
   ```

3. **应用无法启动**
   - 检查 Info.plist 中的 CFBundleExecutable 是否与实际可执行文件名匹配
   - 确保所有必要的 .dylib 文件都已复制

4. **NuGet 权限警告**
   ```bash
   # 修复 NuGet 目录权限
   sudo chown -R $(whoami) ~/.local/share/NuGet
   ```

### 调试技巧

1. **验证 .app 包结构**
   ```bash
   find YourApp.app -type f -exec ls -la {} \;
   ```

2. **检查依赖关系**
   ```bash
   otool -L YourApp.app/Contents/MacOS/YourExecutable
   ```

3. **测试应用启动**
   ```bash
   # 从命令行启动以查看错误信息
   ./YourApp.app/Contents/MacOS/YourExecutable
   ```

## 高级选项

### 添加应用图标

1. 创建 .icns 图标文件：
   ```bash
   # 使用 sips 工具转换 PNG 到 ICNS
   sips -s format icns icon.png --out icon.icns
   ```

2. 复制到应用包：
   ```bash
   cp icon.icns YourApp.app/Contents/Resources/
   ```

### 代码签名（生产环境）

对于 App Store 或公开分发，您需要使用有效的开发者证书：

```bash
# 使用开发者证书签名
codesign --force --deep --sign "Developer ID Application: Your Name" YourApp.app

# 公证（macOS 10.15+）
xcrun notarytool submit YourApp.dmg \
    --apple-id your-apple-id@example.com \
    --password your-app-specific-password \
    --team-id YOUR_TEAM_ID \
    --wait
```

### 构建通用二进制文件

为了支持 Intel 和 Apple Silicon Mac：

```bash
# 发布 Intel 版本
dotnet publish -r osx-x64 -c Release -p:PublishAot=true

# 发布 ARM64 版本
dotnet publish -r osx-arm64 -c Release -p:PublishAot=true

# 使用 lipo 合并二进制文件
lipo -create \
    path/to/osx-x64/YourApp \
    path/to/osx-arm64/YourApp \
    -output YourApp.app/Contents/MacOS/YourApp
```

## 许可证

本文档采用 MIT 许可证。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进本指南。

---

**注意：** 本指南基于 .NET 9.0 和 Avalonia 11.x 版本。对于不同版本，可能需要调整相应的配置。