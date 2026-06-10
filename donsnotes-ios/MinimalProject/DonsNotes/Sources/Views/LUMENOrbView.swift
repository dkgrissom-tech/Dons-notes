import SwiftUI

// MARK: - LUMEN Orb States
enum LUMENOrbState {
    case idle
    case listening
    case triggered
    case responding
    case dormant
}

// MARK: - Pre-computed values (no math inside @ViewBuilder)
private struct OrbFrame {
    let orbScale: CGFloat
    let glowOpacity: Double
    let ripples: [(scale: CGFloat, opacity: Double)]  // 3 rings
    let arcDegrees: Double
    let showArc: Bool

    init(state: LUMENOrbState, amp: Float, pulse: Bool, t: Double) {
        let pulseRange: CGFloat = (state == .idle || state == .dormant) ? 0.05 : 0.12
        let base: CGFloat       = 1.0 + (pulse ? pulseRange : 0.0)
        let boost: CGFloat      = amp > 0.05 ? CGFloat(amp) * 0.25 : 0.0
        self.orbScale           = base + boost
        self.glowOpacity        = 0.45 + Double(amp) * 0.35
        self.showArc            = (state == .responding || state == .triggered)
        self.arcDegrees         = (t * 150).truncatingRemainder(dividingBy: 360)

        // 3 ripple rings: period=2s, delays 0/0.6/1.2, scale 0.8→2.5, opacity 0.8→0
        let period = 2.0
        self.ripples = [0.0, 0.6, 1.2].map { delay in
            var phase = ((t - delay).truncatingRemainder(dividingBy: period)) / period
            if phase < 0 { phase += 1.0 }
            return (CGFloat(0.8 + phase * 1.7), (1.0 - phase) * 0.5)
        }
    }
}

// MARK: - LUMENOrbView
// Matches the Jarvis web app:
//   • Solid filled dark navy sphere (not just rings)
//   • State-color rim: idle=cyan, listening=green, responding=purple, triggered=white
//   • Soft glow + 3 expanding ripple rings (CSS-port)
//   • Pulse: idle 1.0↔1.05 slow, active 1.0↔1.12 fast
//   • Voice amplitude boosts scale in real-time
struct LUMENOrbView: View {
    let state: LUMENOrbState
    @ObservedObject var speechService: SpeechRecognizerService
    var size: CGFloat = 160

    @State private var pulse: Bool = false

    private var stateColor: Color {
        switch state {
        case .idle:       return Color(red: 0.22, green: 0.74, blue: 1.00)
        case .listening:  return Color(red: 0.10, green: 0.95, blue: 0.60)
        case .triggered:  return .white
        case .responding: return Color(red: 0.65, green: 0.35, blue: 1.00)
        case .dormant:    return Color(red: 0.22, green: 0.74, blue: 1.00).opacity(0.3)
        }
    }

    private var pulseDuration: Double {
        switch state {
        case .idle, .dormant: return 1.5
        case .listening:      return 0.4
        case .triggered:      return 0.2
        case .responding:     return 0.25
        }
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            orbCanvas(
                frame: OrbFrame(
                    state: state,
                    amp: speechService.audioLevel,
                    pulse: pulse,
                    t: ctx.date.timeIntervalSinceReferenceDate
                )
            )
        }
        .frame(width: size * 1.7, height: size * 1.7 + 28)
        .onAppear { startPulse() }
        .onChange(of: state) { _, _ in
            pulse = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { startPulse() }
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    // All @ViewBuilder work lives here, receives pre-computed values — no let bindings
    @ViewBuilder
    private func orbCanvas(frame: OrbFrame) -> some View {
        ZStack {
            // Outer ambient radial glow
            Circle()
                .fill(RadialGradient(
                    colors: [stateColor.opacity(frame.glowOpacity * 0.6), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.85
                ))
                .frame(width: size * 1.7, height: size * 1.7)

            // 3 expanding ripple rings (CSS @keyframes ripple port)
            rippleRing(ripple: frame.ripples[0])
            rippleRing(ripple: frame.ripples[1])
            rippleRing(ripple: frame.ripples[2])

            // Solid sphere body
            sphereBody(orbScale: frame.orbScale, glowOpacity: frame.glowOpacity)

            // Rotating arc when responding/triggered
            if frame.showArc {
                arcRing(degrees: frame.arcDegrees)
            }

            // LUMEN label below sphere
            VStack {
                Spacer().frame(height: size + 28)
                Text("LUMEN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(stateColor.opacity(0.7))
                    .tracking(3)
            }
            .frame(width: size * 1.7)
        }
    }

    @ViewBuilder
    private func rippleRing(ripple: (scale: CGFloat, opacity: Double)) -> some View {
        Circle()
            .stroke(stateColor.opacity(ripple.opacity), lineWidth: 1)
            .frame(width: size, height: size)
            .scaleEffect(ripple.scale)
    }

    @ViewBuilder
    private func sphereBody(orbScale: CGFloat, glowOpacity: Double) -> some View {
        ZStack {
            // Dark filled navy body — the Jarvis solid sphere look
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 0.08, green: 0.13, blue: 0.22),
                        Color(red: 0.03, green: 0.05, blue: 0.12),
                    ],
                    center: UnitPoint(x: 0.38, y: 0.32),
                    startRadius: 0,
                    endRadius: size * 0.48
                ))
                .frame(width: size, height: size)

            // State-color rim ring (the cyan border around the Jarvis orb)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            stateColor.opacity(0.9),
                            stateColor.opacity(0.4),
                            stateColor.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: size, height: size)

            // Specular highlight
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.25), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.18
                ))
                .frame(width: size * 0.38, height: size * 0.25)
                .offset(x: -size * 0.14, y: -size * 0.18)

            // Mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: size * 0.22, weight: .medium))
                .foregroundColor(stateColor.opacity(0.85))
        }
        .scaleEffect(orbScale)
        .shadow(color: stateColor.opacity(glowOpacity), radius: 20)
    }

    @ViewBuilder
    private func arcRing(degrees: Double) -> some View {
        Circle()
            .trim(from: 0, to: 0.3)
            .stroke(stateColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size + 14, height: size + 14)
            .rotationEffect(.degrees(degrees - 90))
            .opacity(0.8)
    }
}

// MARK: - Wave Bar
private struct WaveBarFrame {
    let height: CGFloat
    init(amplitude: Float, index: Int, totalBars: Int, t: Double) {
        let amp   = CGFloat(amplitude)
        let phase = Double(index) / Double(totalBars) * .pi * 2.0
        let idle  = CGFloat(4 + 10 * (0.5 + 0.5 * sin(t * 3.5 + phase)))
        let wave  = CGFloat(0.2 + 0.8 * abs(sin(t * 7.0 + phase)))
        let active = CGFloat(4) + 54 * amp * wave
        self.height = amp < 0.04 ? idle : max(idle, active)
    }
}

struct LUMENWaveBar: View {
    let amplitude: Float
    let index: Int
    let totalBars: Int

    var body: some View {
        TimelineView(.animation) { ctx in
            waveBarCanvas(f: WaveBarFrame(
                amplitude: amplitude,
                index: index,
                totalBars: totalBars,
                t: ctx.date.timeIntervalSinceReferenceDate
            ))
        }
    }

    @ViewBuilder
    private func waveBarCanvas(f: WaveBarFrame) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.74, blue: 1.00).opacity(0.9),
                    Color(red: 0.22, green: 0.74, blue: 1.00).opacity(0.4),
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: 3, height: f.height)
    }
}

// MARK: - Waveform Row
struct LUMENWaveformView: View {
    @ObservedObject var speechService: SpeechRecognizerService

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<32, id: \.self) { i in
                LUMENWaveBar(amplitude: speechService.audioLevel, index: i, totalBars: 32)
            }
        }
        .frame(height: 60)
    }
}

// MARK: - LUMEN Response Overlay
struct LUMENResponseOverlay: View {
    let question: String
    let answer: String
    let isVisible: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(LM.Colors.cyan)
                Text("LUMEN")
                    .font(LM.Fonts.mono(11, weight: .bold))
                    .foregroundColor(LM.Colors.cyan)
                    .tracking(2)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(LM.Colors.textTertiary)
                }
            }

            ScanLineDivider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11))
                    .foregroundColor(LM.Colors.textTertiary)
                    .padding(.top, 2)
                Text(question)
                    .font(LM.Fonts.text(13))
                    .foregroundColor(LM.Colors.textSecondary)
                    .italic()
            }

            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LM.Colors.cyanGlow)
                        .frame(width: 22, height: 22)
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(LM.Colors.cyan)
                }
                .padding(.top, 1)
                Text(answer)
                    .font(LM.Fonts.text(14))
                    .foregroundColor(LM.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LM.Space.md)
        .background(LM.Colors.surface)
        .cornerRadius(LM.Radius.lg)
        .overlay(RoundedRectangle(cornerRadius: LM.Radius.lg)
            .stroke(LM.Colors.borderCyan, lineWidth: 1))
        .shadow(color: LM.Colors.cyan.opacity(0.2), radius: 20, x: 0, y: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .padding(.horizontal, LM.Space.md)
    }
}
