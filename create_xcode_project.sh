#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="AtoASync"
XCODE_PROJECT="${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj"

echo "🚀 创建 Xcode 项目..."

cd "$PROJECT_DIR"

if [ -d "${PROJECT_NAME}.xcodeproj" ]; then
    echo "⚠️  项目已存在，删除旧项目..."
    rm -rf "${PROJECT_NAME}.xcodeproj"
fi

mkdir -p "${PROJECT_NAME}"

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

echo "📁 创建项目目录结构..."
mkdir -p "${PROJECT_NAME}/Sources/Models"
mkdir -p "${PROJECT_NAME}/Sources/Services"
mkdir -p "${PROJECT_NAME}/Sources/ViewModels"
mkdir -p "${PROJECT_NAME}/Sources/Views"

echo "📝 复制源代码文件..."
if [ -d "Sources" ]; then
    cp -r Sources/* "${PROJECT_NAME}/Sources/" 2>/dev/null || true
fi

echo "✅ 项目结构创建完成"
echo ""
echo "📋 下一步："
echo "1. 在 Finder 中双击打开 ${PROJECT_NAME}.xcodeproj"
echo "2. 或运行: open ${PROJECT_NAME}.xcodeproj"
echo "3. 在 Xcode 中选择 Signing & Capabilities 配置开发团队"
echo "4. 按 ⌘B 构建项目"
echo ""
echo "🎉 准备就绪！"
