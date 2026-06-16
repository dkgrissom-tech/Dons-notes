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
    // Jarvis ring angles — 3 arcs at different speeds/directions
    let ring1Degrees: Double   // inner: fast CW
    let ring2Degrees: Double   // middle: medium CCW
    let ring3Degrees: Double   // outer: slow CW
    let ringOpacity: Double    // overall ring brightness based on state
    let ringSpeedMult: Double  // speed multiplier based on state
    let r1d: CGFloat           // inner ring diameter
    let r2d: CGFloat           // middle ring diameter
    let r3d: CGFloat           // outer ring diameter

    init(state: LUMENOrbState, amp: Float, pulse: Bool, t: Double, size: CGFloat = 160) {
        let pulseRange: CGFloat = (state == .idle || state == .dormant) ? 0.05 : 0.12
        let base: CGFloat       = 1.0 + (pulse ? pulseRange : 0.0)
        let boost: CGFloat      = amp > 0.05 ? CGFloat(amp) * 0.25 : 0.0
        self.orbScale           = base + boost
        self.glowOpacity        = 0.45 + Double(amp) * 0.35

        // Ring brightness + speed per state
        switch state {
        case .dormant:
            self.ringOpacity   = 0.45   // raised: orb must be clearly visible on setup screen
            self.ringSpeedMult = 0.3
        case .idle:
            self.ringOpacity   = 0.55   // raised: more visible when not recording
            self.ringSpeedMult = 0.6
        case .listening:
            self.ringOpacity   = 0.75 + Double(amp) * 0.25
            self.ringSpeedMult = 1.0  + Double(amp) * 0.8
        case .triggered:
            self.ringOpacity   = 1.0
            self.ringSpeedMult = 2.2
        case .responding:
            self.ringOpacity   = 0.90
            self.ringSpeedMult = 1.6
        }

        // Ring 1: inner, CW, 1.8s/rev  → 200°/s
        self.ring1Degrees = (t * 200 * self.ringSpeedMult).truncatingRemainder(dividingBy: 360)
        // Ring 2: middle, CCW, 2.8s/rev → 128°/s (negative = counter-clockwise)
        self.ring2Degrees = -(t * 128 * self.ringSpeedMult).truncatingRemainder(dividingBy: 360)
        // Ring 3: outer, CW, 4.2s/rev  → 86°/s
        self.ring3Degrees = (t * 86  * self.ringSpeedMult).truncatingRemainder(dividingBy: 360)
        // Ring diameters scale with orb size (+8%, +20%, +32%)
        self.r1d = size * 1.08
        self.r2d = size * 1.20
        self.r3d = size * 1.32

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
                    t: ctx.date.timeIntervalSinceReferenceDate,
                    size: size
                )
            )
        }
        .frame(width: size * 2.0, height: size * 2.0 + 28)   // wider frame so outer rings don't clip
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

            // ── Jarvis Arc Reactor Rings ──────────────────────────────────
            // Ring diameters are pre-computed in OrbFrame (no let bindings here)

            // Ring 3 (outermost): thin slow orbit
            jarvisArc(
                diameter: frame.r3d,
                trimLength: 0.06,
                degrees: frame.ring3Degrees,
                lineWidth: 1.5,
                opacity: frame.ringOpacity * 0.45
            )
            // Ring 3 counter-arc (ghost tail, 180° offset)
            jarvisArc(
                diameter: frame.r3d,
                trimLength: 0.03,
                degrees: frame.ring3Degrees + 180,
                lineWidth: 1.0,
                opacity: frame.ringOpacity * 0.18
            )

            // Ring 2 (middle): counter-clockwise, medium
            jarvisArc(
                diameter: frame.r2d,
                trimLength: 0.12,
                degrees: frame.ring2Degrees,
                lineWidth: 2.0,
                opacity: frame.ringOpacity * 0.65
            )
            // Ring 2 counter-arc
            jarvisArc(
                diameter: frame.r2d,
                trimLength: 0.05,
                degrees: frame.ring2Degrees + 180,
                lineWidth: 1.0,
                opacity: frame.ringOpacity * 0.22
            )

            // Ring 1 (innermost): fast, brightest
            jarvisArc(
                diameter: frame.r1d,
                trimLength: 0.22,
                degrees: frame.ring1Degrees,
                lineWidth: 2.5,
                opacity: frame.ringOpacity
            )
            // Ring 1 highlight dot at leading tip
            jarvisArcTip(
                diameter: frame.r1d,
                degrees: frame.ring1Degrees,
                opacity: frame.ringOpacity
            )
            // ─────────────────────────────────────────────────────────────

            // Solid sphere body (drawn AFTER rings so it sits on top)
            sphereBody(orbScale: frame.orbScale, glowOpacity: frame.glowOpacity)

            // LUMEN label below sphere
            VStack {
                Spacer().frame(height: size + 28)
                Text("ORA")
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

    // Jarvis arc: a trimmed circle arc at a given angle
    @ViewBuilder
    private func jarvisArc(
        diameter: CGFloat,
        trimLength: CGFloat,
        degrees: Double,
        lineWidth: CGFloat,
        opacity: Double
    ) -> some View {
        Circle()
            .trim(from: 0, to: trimLength)
            .stroke(
                LinearGradient(
                    colors: [stateColor, stateColor.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(degrees - 90))
            .opacity(opacity)
    }

    // Bright dot at the leading tip of Ring 1 — the "energy head" of the arc
    @ViewBuilder
    private func jarvisArcTip(diameter: CGFloat, degrees: Double, opacity: Double) -> some View {
        Circle()
            .fill(stateColor)
            .frame(width: 5, height: 5)
            .offset(y: -(diameter / 2))
            .rotationEffect(.degrees(degrees - 90))
            .opacity(opacity)
            .shadow(color: stateColor, radius: 4)
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
                Text("ORA")
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
