import SwiftUI

// MARK: - LUMEN Orb States
enum LUMENOrbState {
    case idle
    case listening
    case triggered      // brief flash when "Hey Lumen" fires
    case responding     // thinking / speaking
    case dormant
}

// MARK: - Orb computed values (plain struct, NOT a @ViewBuilder)
// All per-frame math lives here so the SwiftUI body stays declarative.
private struct Ripple: Identifiable {
    let id: Int
    let scale: CGFloat
    let opacity: Double
}

private struct OrbValues {
    let scale: CGFloat            // core orb scale (base pulse * amp boost)
    let color: Color              // state-driven core/ring color
    let glow: Double              // ambient glow opacity 0...1
    let midRingOpacity: Double
    let ripples: [Ripple]         // 3 ripples, fully computed (scale + opacity)

    init(state: LUMENOrbState, amp: CGFloat, t: Double, pulse: Bool) {
        // Base pulse range per state (matches Jarvis: idle 1.0–1.05, active 1.0–1.12)
        let activeRange: CGFloat
        switch state {
        case .idle, .dormant:                 activeRange = 0.05
        case .listening, .triggered, .responding: activeRange = 0.12
        }
        // withAnimation drives `pulse` between false/true; map to the scale range.
        let basePulse = 1.0 + (pulse ? activeRange : 0.0)

        // audioLevel boost rides on top of the base pulse (only when meaningful)
        let ampBoost: CGFloat = amp > 0.05 ? (amp * 0.3) : 0.0
        self.scale = basePulse + ampBoost

        // Color by state (matches Jarvis palette)
        switch state {
        case .idle:       self.color = LM.Colors.cyanDim
        case .listening:  self.color = LM.Colors.green
        case .triggered:  self.color = LM.Colors.cyanBright
        case .responding: self.color = LM.Colors.purple
        case .dormant:    self.color = LM.Colors.cyan.opacity(0.25)
        }

        // Ambient glow strength
        switch state {
        case .idle:       self.glow = 0.30 + Double(amp) * 0.30
        case .listening:  self.glow = 0.55 + Double(amp) * 0.45
        case .triggered:  self.glow = 0.95
        case .responding: self.glow = 0.70
        case .dormant:    self.glow = 0.12
        }

        self.midRingOpacity = 0.35 + self.glow * 0.4

        // 3 expanding ripple rings — staggered phase offsets, period 2s (matches CSS ripple).
        // Fully compute scale (0.8 → 2.5) and opacity (0.8 → 0) here so the view does no math.
        let period = 2.0
        let delays = [0.0, 0.6, 1.2]   // staggered like .ripple:nth-child(2)/(3)
        self.ripples = delays.enumerated().map { idx, d in
            var phase = ((t - d).truncatingRemainder(dividingBy: period)) / period
            if phase < 0 { phase += 1.0 }
            let s = 0.8 + CGFloat(phase) * (2.5 - 0.8)
            let o = (1.0 - phase) * 0.8
            return Ripple(id: idx, scale: s, opacity: o)
        }
    }
}

// MARK: - LUMEN Orb View
struct LUMENOrbView: View {
    let state: LUMENOrbState
    @ObservedObject var speechService: SpeechRecognizerService
    var size: CGFloat = 160

    @State private var pulse: Bool = false

    private var coreSize: CGFloat { size * 0.42 }

    var body: some View {
        // TimelineView(.animation) redraws every frame so the ripple phase (driven by the
        // timeline date) and the latest audioLevel both stay current with no timer fight.
        // `pulse` is animated separately by withAnimation(.repeatForever) and toggles the
        // base scale between the idle/active range.
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let amp = CGFloat(speechService.audioLevel)
            let v = OrbValues(state: state, amp: amp, t: t, pulse: pulse)
            canvas(v: v, t: t)
        }
        .frame(width: size * 1.8, height: size * 1.8)
        .onAppear { startPulse() }
        .onChange(of: state) { _, _ in startPulse() }
    }

    // Animate the base breathing pulse. Re-arm on appear and on state change so the
    // duration matches the active state (faster when listening/speaking).
    private func startPulse() {
        pulse = false
        let duration: Double
        switch state {
        case .idle, .dormant: duration = 1.5    // pulse-slow (3s round trip)
        case .listening:      duration = 0.4    // pulse-fast 0.8s round trip
        case .triggered:      duration = 0.4
        case .responding:     duration = 0.25   // speaking 0.5s round trip
        }
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    @ViewBuilder
    private func canvas(v: OrbValues, t: Double) -> some View {
        ZStack {
            // Outer ambient glow
            Circle()
                .fill(RadialGradient(
                    colors: [v.color.opacity(v.glow * 0.55), .clear],
                    center: .center, startRadius: 0, endRadius: size * 0.9
                ))
                .frame(width: size * 1.8, height: size * 1.8)

            // 3 expanding ripple rings (CSS @keyframes ripple port).
            ForEach(v.ripples) { r in
                Circle()
                    .stroke(v.color.opacity(r.opacity), lineWidth: 1)
                    .frame(width: size, height: size)
                    .scaleEffect(r.scale)
            }

            // Mid structural ring
            Circle()
                .stroke(v.color.opacity(v.midRingOpacity), lineWidth: 1.5)
                .frame(width: size, height: size)
                .scaleEffect(v.scale)

            // Responding rotating arc
            if state == .responding {
                let arcDeg = (t * 160.0).truncatingRemainder(dividingBy: 360)
                Circle()
                    .trim(from: 0.0, to: 0.35)
                    .stroke(v.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size + 16, height: size + 16)
                    .rotationEffect(.degrees(arcDeg - 90))
            }

            // Core orb
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [
                            v.color.opacity(0.95),
                            v.color.opacity(0.60),
                            LM.Colors.blue.opacity(0.35),
                            LM.Colors.deep
                        ],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: coreSize * 0.9
                    ))
                    .frame(width: coreSize, height: coreSize)

                // Specular highlight
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.78), .clear],
                        center: .center, startRadius: 0, endRadius: coreSize * 0.3
                    ))
                    .frame(width: coreSize * 0.45, height: coreSize * 0.30)
                    .offset(x: -coreSize * 0.15, y: -coreSize * 0.20)

                Text("LUMEN")
                    .font(LM.Fonts.mono(coreSize * 0.13, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(2)
            }
            .scaleEffect(v.scale)
            .shadow(color: v.color.opacity(v.glow), radius: 18 + v.glow * 14)
        }
    }
}

// MARK: - LUMEN Wave Bar
struct LUMENWaveBar: View {
    let amplitude: Float
    let index: Int
    let totalBars: Int

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let amp = CGFloat(amplitude)
            let phase = Double(index) / Double(totalBars) * .pi * 2.0

            let idleH = 4 + 10 * CGFloat(0.5 + 0.5 * sin(t * 3.5 + phase))
            let waveVar = 0.20 + 0.80 * abs(sin(t * 7.0 + phase))
            let activeH = 4 + 54 * amp * CGFloat(waveVar)
            let height = amp < 0.04 ? idleH : max(idleH, activeH)

            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    colors: [
                        LM.Colors.cyanBright.opacity(0.88 + Double(amp) * 0.12),
                        LM.Colors.cyan.opacity(0.42)
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 3, height: height)
        }
    }
}

// MARK: - LUMEN Waveform Row
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
                    .font(LM.Fonts.text(13, weight: .bold))
                    .foregroundColor(LM.Colors.cyan)
                Text("LUMEN")
                    .font(LM.Fonts.mono(11, weight: .bold))
                    .foregroundColor(LM.Colors.cyan)
                    .tracking(2)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(LM.Fonts.text(16))
                        .foregroundColor(LM.Colors.textTertiary)
                }
            }

            ScanLineDivider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(LM.Fonts.text(11))
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
                        .font(LM.Fonts.text(10, weight: .bold))
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
