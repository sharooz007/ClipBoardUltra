import SwiftUI
import Cocoa

/// Visual language: a desk instrument that prints your clipboard.
/// Gunmetal chassis, a roll of cool thermal paper for the history, keycaps for actions,
/// an amber readout for live state, and one safety-orange key for the action that matters.
enum Theme {
    // Chassis
    static let chassisTop   = Color(hex: 0x2A2D31)
    static let chassis      = Color(hex: 0x1E2023)
    static let chassisLow   = Color(hex: 0x141517)
    static let screen       = Color(hex: 0x101113)
    static let hairline     = Color.white.opacity(0.07)

    // Legends on the chassis
    static let bone         = Color(hex: 0xE3E0D7)
    static let boneDim      = Color(hex: 0xA6A49D)

    // Paper roll
    static let paper        = Color(hex: 0xE9ECE7)
    static let paperShade   = Color(hex: 0xDCE0DA)
    static let perforation  = Color(hex: 0xAEB3AC)
    static let ink          = Color(hex: 0x1C1F23)
    static let inkFaded     = Color(hex: 0x555A62)

    // Signals
    static let orange       = Color(hex: 0xFF6A1A)
    static let orangeDeep   = Color(hex: 0xC94B0C)
    static let amber        = Color(hex: 0xFFB547)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Keycaps

/// A physical-feeling key: a darker skirt under a lighter top face, with real travel on press.
struct KeycapStyle: ButtonStyle {
    enum Tone { case graphite, bone, orange }

    var tone: Tone = .graphite
    var lit: Bool = false
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        KeycapBody(configuration: configuration, tone: tone, lit: lit, compact: compact)
    }

    private struct KeycapBody: View {
        let configuration: Configuration
        let tone: Tone
        let lit: Bool
        let compact: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            let pressed = configuration.isPressed
            let travel: CGFloat = compact ? 1.5 : 2

            HStack(spacing: 6) {
                if lit {
                    Circle()
                        .fill(Theme.amber)
                        .frame(width: 5, height: 5)
                        .shadow(color: Theme.amber.opacity(0.8), radius: 2, y: 0.5)
                }
                configuration.label
            }
            .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, compact ? 8 : 11)
            .frame(height: compact ? 22 : 26)
            .background(
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(skirt)
                    RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                        .fill(LinearGradient(colors: face, startPoint: .top, endPoint: .bottom))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                .stroke(Color.white.opacity(tone == .graphite ? 0.07 : 0.35), lineWidth: 0.5)
                        )
                        .padding(.bottom, pressed ? 0.5 : travel)
                        .brightness(hovering && !pressed ? 0.04 : 0)
                }
            )
            .offset(y: pressed ? travel - 0.5 : 0)
            .shadow(color: .black.opacity(0.45), radius: pressed ? 0.5 : 1.5, x: 0, y: pressed ? 0.5 : 1.5)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.07), value: pressed)
            .onHover { hovering = $0 }
            .contentShape(Rectangle())
        }

        private var foreground: Color {
            switch tone {
            case .graphite: return lit ? Theme.bone : Theme.boneDim
            case .bone: return Theme.ink
            case .orange: return Color(hex: 0x1A0D05)
            }
        }

        private var face: [Color] {
            switch tone {
            case .graphite: return lit ? [Color(hex: 0x3A3E44), Color(hex: 0x2F3237)] : [Color(hex: 0x34373C), Color(hex: 0x2A2D31)]
            case .bone: return [Color(hex: 0xEEEBE3), Color(hex: 0xD6D2C8)]
            case .orange: return [Color(hex: 0xFF8238), Theme.orange]
            }
        }

        private var skirt: Color {
            switch tone {
            case .graphite: return Color(hex: 0x16171A)
            case .bone: return Color(hex: 0x9F9B91)
            case .orange: return Theme.orangeDeep
            }
        }
    }
}

/// A small, non-interactive key legend used in the footer cheat sheet.
struct KeyLegend: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(Theme.mono(9.5, .semibold))
                .foregroundColor(Theme.bone)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 17)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: 0x2E3135))
                        .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 1)
                )
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(Theme.boneDim)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Logo mark

/// The ClipBoardUltra mark: a slip of paper feeding out of a printer slot, torn edge at the bottom.
struct LogoMark: View {
    var size: CGFloat = 22

    var body: some View {
        Canvas { ctx, canvas in
            let s = canvas.width / 24
            // Slot
            let slot = Path(roundedRect: CGRect(x: 1.5 * s, y: 3 * s, width: 21 * s, height: 4 * s), cornerRadius: 2 * s)
            ctx.fill(slot, with: .color(Theme.chassisLow))
            ctx.stroke(slot, with: .color(Theme.boneDim.opacity(0.6)), lineWidth: 0.8 * s)
            // Slip
            ctx.fill(LogoGeometry.slip(scale: s), with: .color(Theme.paper))
            // Orange key + ink lines on the slip
            ctx.fill(Path(roundedRect: CGRect(x: 6.5 * s, y: 9 * s, width: 3 * s, height: 3 * s), cornerRadius: 0.8 * s), with: .color(Theme.orange))
            ctx.fill(Path(roundedRect: CGRect(x: 11 * s, y: 9.8 * s, width: 6.5 * s, height: 1.5 * s), cornerRadius: 0.75 * s), with: .color(Theme.ink))
            ctx.fill(Path(roundedRect: CGRect(x: 6.5 * s, y: 14 * s, width: 11 * s, height: 1.3 * s), cornerRadius: 0.65 * s), with: .color(Theme.inkFaded))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum LogoGeometry {
    /// Slip outline in a 24-unit box (top-left origin): hangs from the slot, zig-zag tear at y≈21.
    static func slip(scale s: CGFloat) -> Path {
        var p = Path()
        let left = 4.5 * s, right = 19.5 * s, top = 5 * s, bottom = 20 * s
        p.move(to: CGPoint(x: left, y: top))
        p.addLine(to: CGPoint(x: right, y: top))
        p.addLine(to: CGPoint(x: right, y: bottom))
        let teeth = 5
        let w = (right - left) / CGFloat(teeth)
        for i in 0..<teeth {
            let x0 = right - CGFloat(i) * w
            p.addLine(to: CGPoint(x: x0 - w / 2, y: bottom + 1.6 * s))
            p.addLine(to: CGPoint(x: x0 - w, y: bottom))
        }
        p.closeSubpath()
        return p
    }
}

/// Template image for the menu bar (renders black/white automatically).
enum MenuBarGlyph {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            let s = rect.width / 24
            NSColor.black.setFill()
            NSColor.black.setStroke()

            let slot = NSBezierPath(roundedRect: NSRect(x: 1.5 * s, y: 3 * s, width: 21 * s, height: 3.6 * s), xRadius: 1.8 * s, yRadius: 1.8 * s)
            slot.lineWidth = 1.6 * s
            slot.stroke()

            // Slip with two cut-out lines
            let slip = NSBezierPath()
            let left = 5.0 * s, right = 19.0 * s, top = 6.6 * s, bottom = 19.5 * s
            slip.move(to: NSPoint(x: left, y: top))
            slip.line(to: NSPoint(x: right, y: top))
            slip.line(to: NSPoint(x: right, y: bottom))
            let teeth = 4
            let w = (right - left) / CGFloat(teeth)
            for i in 0..<teeth {
                let x0 = right - CGFloat(i) * w
                slip.line(to: NSPoint(x: x0 - w / 2, y: bottom + 2 * s))
                slip.line(to: NSPoint(x: x0 - w, y: bottom))
            }
            slip.close()
            slip.fill()

            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(roundedRect: NSRect(x: 7.5 * s, y: 10 * s, width: 9 * s, height: 1.8 * s), xRadius: 0.9 * s, yRadius: 0.9 * s).fill()
            NSBezierPath(roundedRect: NSRect(x: 7.5 * s, y: 14 * s, width: 6 * s, height: 1.8 * s), xRadius: 0.9 * s, yRadius: 0.9 * s).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ClipBoardUltra"
        return image
    }
}

// MARK: - Perforation

/// Dashed tear line between slips on the paper roll.
struct Perforation: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(Theme.perforation, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}
