import SwiftUI

/// 深色工作台主题 token。所有视图的颜色、间距、圆角只从这里取，
/// 不在视图内散落硬编码。取值见 spec
/// docs/superpowers/specs/2026-07-07-macos-ui-redesign-design.md。
enum Theme {
    // 色板
    static let bg = Color(red: 0.118, green: 0.118, blue: 0.137)            // #1E1E23
    static let bgRaised = Color(red: 0.169, green: 0.169, blue: 0.192)      // #2B2B31
    static let bgSidebar = Color(red: 0.110, green: 0.110, blue: 0.129)     // #1C1C21
    static let stroke = Color(red: 0.220, green: 0.220, blue: 0.247)        // #38383F
    static let textPrimary = Color(red: 0.933, green: 0.933, blue: 0.941)   // #EEEEF0
    static let textSecondary = Color(red: 0.604, green: 0.604, blue: 0.639) // #9A9AA3
    static let accent = Color(red: 0.910, green: 0.639, blue: 0.239)        // #E8A33D
    static let statusRunning = Color(red: 0.298, green: 0.851, blue: 0.392) // #4CD964
    static let statusFailed = Color(red: 1.0, green: 0.373, blue: 0.341)    // #FF5F57
    static let statusIdle = textSecondary
    static let toolbarSurface = Color.white.opacity(0.055)
    static let toolbarSurfacePressed = Color.white.opacity(0.11)
    static let toolbarSelection = accent.opacity(0.18)
    static let cardGradient = LinearGradient(
        colors: [
            Color(red: 0.310, green: 0.486, blue: 0.941),                   // #4F7CF0
            Color(red: 0.416, green: 0.361, blue: 0.847),                   // #6A5CD8
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // 间距
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16

    // 圆角
    static let radiusS: CGFloat = 6
    static let radiusL: CGFloat = 10

    // 标题栏
    static let toolbarIconSize: CGFloat = 28
    static let toolbarDividerHeight: CGFloat = 16
}

extension Theme {
    /// 缩略图尺寸 token（原 ThumbnailMetrics，并入主题避免两套常量）。
    enum Thumb {
        static let gridCell: CGFloat = 150
        static let gridGap: CGFloat = 3
        static let gridSize = CGSize(width: gridCell, height: gridCell)
        static let listSize = CGSize(width: 56, height: 42)
        static let inspectorSize = CGSize(width: 240, height: 166)
        static let cornerRadius: CGFloat = Theme.radiusS
    }
}
