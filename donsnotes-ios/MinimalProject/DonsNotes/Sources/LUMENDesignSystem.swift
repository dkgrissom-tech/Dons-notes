import SwiftUI

// MARK: - LUMEN Design System
// True black, electric cyan, holographic HUD aesthetic

struct LM {
    // MARK: Colors
    struct Colors {
        // Backgrounds
        static let void        = Color(red: 0.00, green: 0.00, blue: 0.00) // true black
        static let deep        = Color(red: 0.02, green: 0.04, blue: 0.08) // deep space
        static let surface     = Color(red: 0.05, green: 0.08, blue: 0.13) // panel bg
        static let elevated    = Color(red: 0.08, green: 0.12, blue: 0.18) // elevated panel
        static let glass       = Color(red: 0.10, green: 0.16, blue: 0.24) // glass card

        // LUMEN Cyan
        static let cyan        = Color(red: 0.00, green: 0.83, blue: 1.00) // #00D4FF
        static let cyanDim     = Color(red: 0.00, green: 0.83, blue: 1.00).opacity(0.6)
        static let cyanGlow    = Color(red: 0.00, green: 0.83, blue: 1.00).opacity(0.15)
        static let cyanBright  = Color(red: 0.40, green: 0.93, blue: 1.00) // highlight

        // Accents
        static let blue        = Color(red: 0.20, green: 0.55, blue: 1.00)
        static let purple      = Color(red: 0.55, green: 0.30, blue: 1.00)
        static let green       = Color(red: 0.10, green: 0.95, blue: 0.60) // success
        static let red         = Color(red: 1.00, green: 0.25, blue: 0.35) // error/record
        static let amber       = Color(red: 1.00, green: 0.75, blue: 0.20) // warning

        // Text
        static let textPrimary   = Color.white
        static let textSecondary = Color(white: 0.70)
        static let textTertiary  = Color(white: 0.42)
        static let textGhost     = Color(white: 0.22)

        // Borders
        static let borderCyan  = Color(red: 0.00, green: 0.83, blue: 1.00).opacity(0.25)
        static let borderDim   = Color(white: 1.0).opacity(0.07)
        static let borderGlass = Color(white: 1.0).opacity(0.04)
    }

    // MARK: Typography
    struct Fonts {
        // Mono for data/numbers — feels like a HUD readout
        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        // Rounded for labels
        static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        // Default
        static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }
    }

    // MARK: Spacing
    struct Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Radius
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 100
    }
}

// MARK: - HUD Card Style
struct LUMENCard<Content: View>: View {
    var borderColor: Color = LM.Colors.borderCyan
    var glowColor: Color = LM.Colors.cyan
    var padding: CGFloat = LM.Space.md
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(LM.Colors.surface)
            .cornerRadius(LM.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: LM.Radius.lg)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: glowColor.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Section Header
struct LUMENSectionHeader: View {
    let title: String
    let icon: String
    var color: Color = LM.Colors.cyan

    var body: some View {
        HStack(spacing: LM.Space.sm) {
            Image(systemName: icon)
                .font(LM.Fonts.text(11, weight: .bold))
                .foregroundColor(color)
            Text(title.uppercased())
                .font(LM.Fonts.mono(10, weight: .bold))
                .foregroundColor(color)
                .tracking(2)
            Spacer()
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
                .frame(maxWidth: 60)
        }
    }
}

// MARK: - Scan Line Divider
struct ScanLineDivider: View {
    var color: Color = LM.Colors.borderCyan
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(color.opacity(0.5)).frame(width: 4, height: 1)
            Rectangle().fill(color.opacity(0.2)).frame(maxWidth: .infinity, maxHeight: 1)
            Rectangle().fill(color.opacity(0.5)).frame(width: 4, height: 1)
        }
    }
}

// MARK: - LUMEN Button
struct LUMENButton: View {
    let title: String
    let icon: String?
    var style: LUMENButtonStyle = .primary
    let action: () -> Void

    enum LUMENButtonStyle {
        case primary, secondary, danger, ghost
        var bg: Color {
            switch self {
            case .primary: return LM.Colors.cyan
            case .secondary: return LM.Colors.surface
            case .danger: return LM.Colors.red
            case .ghost: return .clear
            }
        }
        var fg: Color {
            switch self {
            case .primary: return .black
            case .secondary: return LM.Colors.textPrimary
            case .danger: return .white
            case .ghost: return LM.Colors.cyan
            }
        }
        var border: Color {
            switch self {
            case .primary: return .clear
            case .secondary: return LM.Colors.borderCyan
            case .danger: return .clear
            case .ghost: return LM.Colors.cyan.opacity(0.4)
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(LM.Fonts.text(15, weight: .semibold))
                }
                Text(title)
                    .font(LM.Fonts.rounded(15, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(style.bg)
            .foregroundColor(style.fg)
            .cornerRadius(LM.Radius.md)
            .overlay(RoundedRectangle(cornerRadius: LM.Radius.md).stroke(style.border, lineWidth: 1))
            .shadow(color: style == .primary ? LM.Colors.cyan.opacity(0.3) : .clear, radius: 12, x: 0, y: 4)
        }
    }
}

// MARK: - LUMEN Text Field
struct LUMENTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(LM.Fonts.text(13))
                    .foregroundColor(LM.Colors.textTertiary)
            }
            TextField("", text: $text)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder).foregroundColor(LM.Colors.textGhost)
                }
                .foregroundColor(LM.Colors.textPrimary)
                .font(LM.Fonts.text(14))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LM.Colors.deep)
        .cornerRadius(LM.Radius.sm)
        .overlay(RoundedRectangle(cornerRadius: LM.Radius.sm).stroke(LM.Colors.borderCyan, lineWidth: 1))
    }
}

// MARK: - Status Badge
struct LUMENStatusBadge: View {
    let status: MeetingStatus
    var body: some View {
        HStack(spacing: 5) {
            if status.isProcessing {
                Circle()
                    .fill(status.color)
                    .frame(width: 5, height: 5)
                    .modifier(PulseModifier(color: status.color))
            }
            Text(status.displayName.uppercased())
                .font(LM.Fonts.mono(9, weight: .bold))
                .foregroundColor(status.color)
                .tracking(1.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.12))
        .cornerRadius(LM.Radius.pill)
        .overlay(RoundedRectangle(cornerRadius: LM.Radius.pill).stroke(status.color.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Pulse Modifier
struct PulseModifier: ViewModifier {
    let color: Color
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = 1.6
                }
            }
    }
}

// MARK: - View Extension for placeholder
extension View {
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
