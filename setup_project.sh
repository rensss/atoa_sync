#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="AtoASync"

echo "🚀 开始创建 ${PROJECT_NAME} 项目..."
echo ""

cd "$PROJECT_DIR"

if [ -d "${PROJECT_NAME}.xcodeproj" ]; then
    echo "⚠️  发现已存在的项目，是否删除？(y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        rm -rf "${PROJECT_NAME}.xcodeproj"
        rm -rf "${PROJECT_NAME}"
        echo "✅ 已删除旧项目"
    else
        echo "❌ 操作已取消"
        exit 1
    fi
fi

echo "📦 步骤 1/5: 使用 Xcode 命令行工具创建项目..."

xcodebuild -project "${PROJECT_NAME}.xcodeproj" 2>/dev/null || {
    echo "使用 Swift Package Manager 创建项目..."
    
    mkdir -p "${PROJECT_NAME}"
    cd "${PROJECT_NAME}"
    
    swift package init --type executable --name "${PROJECT_NAME}" 2>/dev/null || echo "初始化..."
    
    cd ..
}

if [ ! -d "${PROJECT_NAME}.xcodeproj" ]; then
    echo "📝 手动创建 Xcode 项目配置..."
    
    mkdir -p "${PROJECT_NAME}.xcodeproj"
    
    cat > "${PROJECT_NAME}.xcodeproj/project.pbxproj" << 'PBXPROJ_EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 55;
	objects = {

/* Begin PBXBuildFile section */
		MAIN_APP /* AtoASyncApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = MAIN_APP_REF /* AtoASyncApp.swift */; };
		ASSETS /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = ASSETS_REF /* Assets.xcassets */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		PRODUCT_REF /* AtoASync.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AtoASync.app; sourceTree = BUILT_PRODUCTS_DIR; };
		MAIN_APP_REF /* AtoASyncApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AtoASyncApp.swift; sourceTree = "<group>"; };
		ASSETS_REF /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
		ENTITLEMENTS_REF /* AtoASync.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = AtoASync.entitlements; sourceTree = "<group>"; };
		INFO_PLIST_REF /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		FRAMEWORKS_PHASE /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		ROOT_GROUP = {
			isa = PBXGroup;
			children = (
				MAIN_GROUP /* AtoASync */,
				PRODUCTS_GROUP /* Products */,
			);
			sourceTree = "<group>";
		};
		MAIN_GROUP /* AtoASync */ = {
			isa = PBXGroup;
			children = (
				SOURCES_GROUP /* Sources */,
				ASSETS_REF /* Assets.xcassets */,
				ENTITLEMENTS_REF /* AtoASync.entitlements */,
				INFO_PLIST_REF /* Info.plist */,
			);
			path = AtoASync;
			sourceTree = "<group>";
		};
		SOURCES_GROUP /* Sources */ = {
			isa = PBXGroup;
			children = (
				MAIN_APP_REF /* AtoASyncApp.swift */,
			);
			path = Sources;
			sourceTree = "<group>";
		};
		PRODUCTS_GROUP /* Products */ = {
			isa = PBXGroup;
			children = (
				PRODUCT_REF /* AtoASync.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		TARGET /* AtoASync */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = BUILD_CONFIG_LIST /* Build configuration list for PBXNativeTarget "AtoASync" */;
			buildPhases = (
				SOURCES_PHASE /* Sources */,
				FRAMEWORKS_PHASE /* Frameworks */,
				RESOURCES_PHASE /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = AtoASync;
			productName = AtoASync;
			productReference = PRODUCT_REF /* AtoASync.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		PROJECT /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1400;
				LastUpgradeCheck = 1400;
			};
			buildConfigurationList = PROJECT_BUILD_CONFIG_LIST /* Build configuration list for PBXProject "AtoASync" */;
			compatibilityVersion = "Xcode 13.0";
			developmentRegion = "zh-Hans";
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
				"zh-Hans",
			);
			mainGroup = ROOT_GROUP;
			productRefGroup = PRODUCTS_GROUP /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				TARGET /* AtoASync */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		RESOURCES_PHASE /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				ASSETS /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		SOURCES_PHASE /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				MAIN_APP /* AtoASyncApp.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		DEBUG_CONFIG /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++17";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 12.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		RELEASE_CONFIG /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++17";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 12.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			};
			name = Release;
		};
		TARGET_DEBUG_CONFIG /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = AtoASync/AtoASync.entitlements;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = AtoASync/Info.plist;
				INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © 2026. All rights reserved.";
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.atoa.AtoASync;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		TARGET_RELEASE_CONFIG /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = AtoASync/AtoASync.entitlements;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = AtoASync/Info.plist;
				INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © 2026. All rights reserved.";
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.atoa.AtoASync;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		PROJECT_BUILD_CONFIG_LIST /* Build configuration list for PBXProject "AtoASync" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				DEBUG_CONFIG /* Debug */,
				RELEASE_CONFIG /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		BUILD_CONFIG_LIST /* Build configuration list for PBXNativeTarget "AtoASync" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				TARGET_DEBUG_CONFIG /* Debug */,
				TARGET_RELEASE_CONFIG /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = PROJECT /* Project object */;
}
PBXPROJ_EOF

fi

echo "✅ 步骤 1 完成"
echo ""

echo "📁 步骤 2/5: 创建项目目录结构..."
mkdir -p "${PROJECT_NAME}"
mkdir -p "${PROJECT_NAME}/Sources"
mkdir -p "${PROJECT_NAME}/Assets.xcassets/AppIcon.appiconset"
mkdir -p "${PROJECT_NAME}/Assets.xcassets/AccentColor.colorset"

echo "📝 步骤 3/5: 创建配置文件..."

cat > "${PROJECT_NAME}/Info.plist" << 'INFO_PLIST_EOF'
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
INFO_PLIST_EOF

cat > "${PROJECT_NAME}/${PROJECT_NAME}.entitlements" << 'ENTITLEMENTS_EOF'
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
ENTITLEMENTS_EOF

cat > "${PROJECT_NAME}/Assets.xcassets/AppIcon.appiconset/Contents.json" << 'APPICON_EOF'
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
APPICON_EOF

cat > "${PROJECT_NAME}/Assets.xcassets/AccentColor.colorset/Contents.json" << 'ACCENT_EOF'
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
ACCENT_EOF

cat > "${PROJECT_NAME}/Assets.xcassets/Contents.json" << 'ASSETS_EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
ASSETS_EOF

echo "✅ 步骤 3 完成"
echo ""

echo "📦 步骤 4/5: 复制源代码..."
if [ -d "Sources" ]; then
    cp -r Sources/* "${PROJECT_NAME}/Sources/"
    echo "✅ 源代码复制完成"
else
    echo "⚠️  未找到 Sources 目录"
fi

echo "✅ 步骤 4 完成"
echo ""

echo "🎉 步骤 5/5: 项目创建完成！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ ${PROJECT_NAME} 项目已就绪"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 下一步操作："
echo ""
echo "  方法 1: 使用命令行打开"
echo "  $ open ${PROJECT_NAME}.xcodeproj"
echo ""
echo "  方法 2: 在 Finder 中"
echo "  双击 ${PROJECT_NAME}.xcodeproj 文件"
echo ""
echo "📝 在 Xcode 中："
echo "  1. 选择菜单 Xcode → Preferences → Accounts"
echo "  2. 添加你的 Apple ID（如果需要）"
echo "  3. 选择项目 → Signing & Capabilities"
echo "  4. 选择你的开发团队"
echo "  5. 按 ⌘B 构建项目"
echo "  6. 按 ⌘R 运行应用"
echo ""
echo "🚀 开始开发吧！"
