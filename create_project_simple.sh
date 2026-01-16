#!/bin/bash

# 简化版本的项目创建脚本
# 使用 Xcode 模板自动创建项目

set -e

PROJECT_NAME="AtoASync"
BUNDLE_ID="com.atoa.AtoASync"
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🚀 创建 ${PROJECT_NAME} Xcode 项目..."
echo ""

cd "$WORK_DIR"

if [ -d "${PROJECT_NAME}.xcodeproj" ] || [ -d "${PROJECT_NAME}" ]; then
    echo "⚠️  检测到已存在的项目文件"
    echo "是否删除并重新创建？(y/n)"
    read -p "> " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        rm -rf "${PROJECT_NAME}.xcodeproj" "${PROJECT_NAME}" 2>/dev/null
        echo "✅ 已删除旧项目"
    else
        echo "❌ 操作已取消"
        exit 1
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  由于命令行创建 Xcode 项目较复杂"
echo "  建议使用以下方法："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 方法 1: 使用 Xcode GUI（推荐）"
echo ""
echo "  1. 打开 Xcode"
echo "  2. File → New → Project"
echo "  3. 选择 macOS → App"
echo "  4. 填写项目信息："
echo "     - Product Name: ${PROJECT_NAME}"
echo "     - Bundle Identifier: ${BUNDLE_ID}"
echo "     - Interface: SwiftUI"
echo "     - Language: Swift"
echo "  5. 选择保存位置: $WORK_DIR"
echo "  6. 删除自动生成的 ContentView.swift 和 AtoASyncApp.swift"
echo "  7. 将 Sources 文件夹拖入项目"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💻 方法 2: 使用准备好的脚本"
echo ""
echo "  我将为你准备项目目录结构："
echo ""

mkdir -p "${PROJECT_NAME}"
mkdir -p "${PROJECT_NAME}/Sources"

echo "📁 正在复制源代码..."
if [ -d "Sources" ]; then
    cp -r Sources/* "${PROJECT_NAME}/Sources/"
    echo "✅ 源代码已复制到 ${PROJECT_NAME}/Sources/"
fi

cat > "${PROJECT_NAME}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>zh-Hans</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026. All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSDocumentsFolderUsageDescription</key>
	<string>需要访问文档文件夹以同步文件</string>
	<key>NSDesktopFolderUsageDescription</key>
	<string>需要访问桌面文件夹以同步文件</string>
	<key>NSDownloadsFolderUsageDescription</key>
	<string>需要访问下载文件夹以同步文件</string>
	<key>NSRemovableVolumesUsageDescription</key>
	<string>需要访问外部磁盘以同步文件</string>
</dict>
</plist>
EOF

cat > "${PROJECT_NAME}/${PROJECT_NAME}.entitlements" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
	<key>com.apple.security.files.downloads.read-write</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
EOF

mkdir -p "${PROJECT_NAME}/Assets.xcassets/AppIcon.appiconset"
cat > "${PROJECT_NAME}/Assets.xcassets/AppIcon.appiconset/Contents.json" << 'EOF'
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

mkdir -p "${PROJECT_NAME}/Assets.xcassets/AccentColor.colorset"
cat > "${PROJECT_NAME}/Assets.xcassets/AccentColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > "${PROJECT_NAME}/Assets.xcassets/Contents.json" << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ 配置文件已创建"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ 项目目录准备完成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 现在请按照以下步骤操作："
echo ""
echo "  1. 打开 Xcode"
echo "  2. File → New → Project"
echo "  3. 选择 macOS → App"
echo "  4. 填写项目信息："
echo "       Product Name: AtoASync"
echo "       Bundle Identifier: com.atoa.AtoASync"
echo "       Interface: SwiftUI"
echo "       Language: Swift"
echo "  5. 保存位置选择: $WORK_DIR"
echo "  6. 项目创建后："
echo "       - 删除自动生成的 AtoASyncApp.swift"
echo "       - 删除自动生成的 ContentView.swift"
echo "       - 删除自动生成的 Assets.xcassets"
echo "       - 将 ${PROJECT_NAME}/Sources 拖入项目"
echo "       - 将 ${PROJECT_NAME}/Assets.xcassets 拖入项目"
echo "       - 将 ${PROJECT_NAME}/Info.plist 设置为项目 Info.plist"
echo "       - 将 ${PROJECT_NAME}/${PROJECT_NAME}.entitlements 设置为Entitlements"
echo ""
echo "或者查看完整指南: QUICK_START.md"
echo ""
