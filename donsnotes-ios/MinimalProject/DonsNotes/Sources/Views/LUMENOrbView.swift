import SwiftUI

// MARK: - LUMEN Orb States
enum LUMENOrbState {
    case idle        // slow breathing pulse
    case listening   // amplitude-reactive, faster
    case triggered   // bright flash then settle
    case responding  // rotating arc while answering
    case dormant     // minimal, dim
}

// MARK: - LUMEN Orb View
struct LUMENOrbView: View {
    let state: LUMENOrbState
    let amplitude: Float      // 0.0 - 1.0 from AudioRecorder.audioLevel
    var size: CGFloat = 180

    // ── Idle breath ──────────────────────────────────────────────────────────
    @State private var idlePulse: CGFloat = 1.0
    @State private var idleGlow: Double = 0.3

    // ── Ring opacities / scales ───────────────────────────────────────────────
    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring3Scale: CGFloat = 1.0
    @State private var ring1Opacity: Double = 0.4
    @State private var ring2Opacity: Double = 0.2
    @State private var ring3Opacity: Double = 0.10

    // ── Responding arc ────────────────────────────────────────────────────────
    @State private var arcAngle: Double = 0          // driven by Timer
    @State private var arcRunning: Bool = false
    @State private var arcTimer: Timer? = nil

    // ── Trigger flash ─────────────────────────────────────────────────────────
    @State private var triggerFlash: Double = 0

    // ── Idle breath timer ─────────────────────────────────────────────────────
    @State private var breathTimer: Timer? = nil
    @State private var breathExpanded: Bool = false

    private var coreSize: CGFloat { size * 0.38 }
    private var ampBoost: CGFloat { CGFloat(amplitude) * size * 0.25 }

    var body: some View {
        ZStack {
            // ── Outer ambient glow ─────────────────────────────────────────
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            LM.Colors.cyan.opacity(glowForState * 0.6),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.9
                    )
                )
                .frame(width: size * 1.8, height: size * 1.8)
                .animation(.easeInOut(duration: 0.4), value: glowForState)

            // ── Ring 3 (outermost) ─────────────────────────────────────────
            Circle()
                .stroke(LM.Colors.cyan.opacity(ring3Opacity), lineWidth: 1)
                .frame(
                    width:  size + 60 + ampBoost * 0.6,
                    height: size + 60 + ampBoost * 0.6
                )
                .scaleEffect(ring3Scale)
                .animation(.easeInOut(duration: 0.3), value: ring3Opacity)
                .animation(.easeInOut(duration: 0.3), value: ring3Scale)
                .animation(.easeOut(duration: 0.08), value: ampBoost)

            // ── Ring 2 (mid) ───────────────────────────────────────────────
            Circle()
                .stroke(LM.Colors.cyan.opacity(ring2Opacity), lineWidth: 1.5)
                .frame(
                    width:  size + 30 + ampBoost * 0.4,
                    height: size + 30 + ampBoost * 0.4
                )
                .scaleEffect(ring2Scale)
                .animation(.easeInOut(duration: 0.3), value: ring2Opacity)
                .animation(.easeInOut(duration: 0.3), value: ring2Scale)
                .animation(.easeOut(duration: 0.08), value: ampBoost)

            // ── Ring 1 (inner glow ring) ───────────────────────────────────
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            LM.Colors.cyan.opacity(ring1Opacity),
                            LM.Colors.blue.opacity(ring1Opacity * 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(
                    width:  size + ampBoost * 0.3,
                    height: size + ampBoost * 0.3
                )
                .scaleEffect(ring1Scale)
                .animation(.easeInOut(duration: 0.3), value: ring1Opacity)
                .animation(.easeInOut(duration: 0.3), value: ring1Scale)
                .animation(.easeOut(duration: 0.08), value: ampBoost)

            // ── Responding arcs ────────────────────────────────────────────
            if state == .responding {
                Circle()
                    .trim(from: 0.0, to: 0.35)
                    .stroke(
                        LM.Colors.cyan,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: size + 14, height: size + 14)
                    .rotationEffect(.degrees(arcAngle))

                Circle()
                    .trim(from: 0.55, to: 0.75)
                    .stroke(
                        LM.Colors.cyanBright.opacity(0.6),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: size + 22, height: size + 22)
                    .rotationEffect(.degrees(-arcAngle * 0.7))
            }

            // ── Core orb ──────────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                LM.Colors.cyanBright.opacity(0.9),
                                LM.Colors.cyan.opacity(0.6),
                                LM.Colors.blue.opacity(0.4),
                                LM.Colors.deep
                            ],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: coreSize * 0.9
                        )
                    )
                    .frame(
                        width:  coreSize + ampBoost * 0.2,
                        height: coreSize + ampBoost * 0.2
                    )
                    .animation(.easeOut(duration: 0.08), value: ampBoost)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.7), Color.white.opacity(0.0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: coreSize * 0.3
                        )
                    )
                    .frame(width: coreSize * 0.45, height: coreSize * 0.3)
                    .offset(x: -coreSize * 0.15, y: -coreSize * 0.2)

                Text("LUMEN")
                    .font(LM.Fonts.mono(coreSize * 0.13, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2)
            }
            .scaleEffect(coreScale)
            .animation(.easeOut(duration: 0.12), value: coreScale)

            // ── Trigger flash ──────────────────────────────────────────────
            if triggerFlash > 0 {
                Circle()
                    .fill(Color.white.opacity(triggerFlash))
                    .frame(width: size * 1.5, height: size * 1.5)
                    .animation(.easeOut(duration: 0.3), value: triggerFlash)
            }
        }
        .frame(width: size * 1.8, height: size * 1.8)
        .onAppear {
            applyState(state)
        }
        .onChange(of: state) { _, newState in
            applyState(newState)
        }
        .onChange(of: amplitude) { _, newAmp in
            guard state == .listening else { return }
            // Ring scales pulse with voice amplitude
            let boost = CGFloat(newAmp)
            ring1Scale = 1.0 + boost * 0.12
            ring2Scale = 1.0 + boost * 0.07
            ring3Scale = 1.0 + boost * 0.04
            ring1Opacity = 0.55 + Double(boost) * 0.45
            ring2Opacity = 0.25 + Double(boost) * 0.35
        }
    }

    // ── Computed helpers ───────────────────────────────────────────────────
    private var glowForState: Double {
        switch state {
        case .idle:      return idleGlow
        case .listening: return 0.55 + Double(amplitude) * 0.45
        case .triggered: return 0.95
        case .responding: return 0.80
        case .dormant:   return 0.12
        }
    }

    private var coreScale: CGFloat {
        switch state {
        case .idle:      return idlePulse
        case .listening: return 1.0 + CGFloat(amplitude) * 0.18
        case .triggered: return 1.15
        case .responding: return 1.05
        case .dormant:   return 0.95
        }
    }

    // ── State machine ──────────────────────────────────────────────────────
    private func applyState(_ newState: LUMENOrbState) {
        stopBreathTimer()
        stopArcTimer()

        switch newState {
        case .idle:
            ring1Opacity = 0.40; ring2Opacity = 0.20; ring3Opacity = 0.10
            ring1Scale   = 1.0;  ring2Scale   = 1.0;  ring3Scale   = 1.0
            startBreathTimer()

        case .listening:
            idlePulse    = 1.0
            idleGlow     = 0.55
            ring1Opacity = 0.65; ring2Opacity = 0.35; ring3Opacity = 0.18
            ring1Scale   = 1.0;  ring2Scale   = 1.0;  ring3Scale   = 1.0

        case .triggered:
            triggerFlash = 0.85
            idlePulse    = 1.15
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.triggerFlash = 0
                self.idlePulse    = 1.0
                self.idleGlow     = 0.90
                self.ring1Opacity = 1.0
                self.ring2Opacity = 0.60
            }

        case .responding:
            idlePulse    = 1.0
            idleGlow     = 0.80
            ring1Opacity = 0.80; ring2Opacity = 0.45; ring3Opacity = 0.20
            ring1Scale   = 1.0;  ring2Scale   = 1.0;  ring3Scale   = 1.0
            arcAngle     = 0
            startArcTimer()

        case .dormant:
            idlePulse    = 1.0
            idleGlow     = 0.12
            ring1Opacity = 0.12; ring2Opacity = 0.07; ring3Opacity = 0.03
            ring1Scale   = 1.0;  ring2Scale   = 1.0;  ring3Scale   = 1.0
        }
    }

    // ── Breath timer (idle) ────────────────────────────────────────────────
    private func startBreathTimer() {
        breathExpanded = false
        breathTimer = Timer.scheduledTimer(withTimeInterval: 2.4, repeats: true) { _ in
            breathExpanded.toggle()
            withAnimation(.easeInOut(duration: 2.4)) {
                if breathExpanded {
                    idlePulse    = 1.06
                    idleGlow     = 0.40
                    ring1Scale   = 1.04
                    ring2Scale   = 1.03
                    ring3Scale   = 1.02
                    ring1Opacity = 0.50
                    ring2Opacity = 0.28
                    ring3Opacity = 0.14
                } else {
                    idlePulse    = 1.0
                    idleGlow     = 0.28
                    ring1Scale   = 1.0
                    ring2Scale   = 1.0
                    ring3Scale   = 1.0
                    ring1Opacity = 0.35
                    ring2Opacity = 0.18
                    ring3Opacity = 0.08
                }
            }
        }
        breathTimer?.fire()
    }

    private func stopBreathTimer() {
        breathTimer?.invalidate()
        breathTimer = nil
    }

    // ── Arc rotation timer (responding) ───────────────────────────────────
    private func startArcTimer() {
        // Tick at 60fps, rotate 3°/tick = full rotation in ~2 seconds
        arcTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            arcAngle = (arcAngle + 3.0).truncatingRemainder(dividingBy: 360.0)
        }
    }

    private func stopArcTimer() {
        arcTimer?.invalidate()
        arcTimer = nil
        arcAngle = 0
    }
}

// MARK: - LUMEN Wave Bar (waveform visualizer)
struct LUMENWaveBar: View {
    let amplitude: Float
    let index: Int
    let totalBars: Int

    @State private var height: CGFloat = 4

    private var phaseOffset: Double {
        Double(index) / Double(totalBars) * .pi * 2
    }

    private var targetHeight: CGFloat {
        let base: CGFloat = 50
        let minH: CGFloat = 4
        if amplitude < 0.01 {
            // Gentle idle ripple using sine wave
            let idle = 0.12 + 0.08 * sin(phaseOffset * 2)
            return minH + base * CGFloat(idle)
        }
        let wave = 0.3 + 0.7 * abs(sin(phaseOffset + Double(amplitude) * 3))
        return minH + base * CGFloat(amplitude) * CGFloat(wave)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [LM.Colors.cyanBright, LM.Colors.cyan.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3, height: height)
            .onAppear {
                // Start with a gentle idle animation immediately
                withAnimation(
                    .easeInOut(duration: 0.6 + Double(index) * 0.02)
                    .repeatForever(autoreverses: true)
                ) {
                    height = targetHeight
                }
            }
            .onChange(of: amplitude) { _, _ in
                withAnimation(.easeOut(duration: 0.08)) {
                    height = targetHeight
                }
            }
    }
}

// MARK: - LUMEN Waveform Row (32 bars)
struct LUMENWaveformView: View {
    let amplitude: Float

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<32, id: \.self) { i in
                LUMENWaveBar(amplitude: amplitude, index: i, totalBars: 32)
            }
        }
        .frame(height: 54)
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
            // Header
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

            // Question
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

            // Answer
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
        .overlay(
            RoundedRectangle(cornerRadius: LM.Radius.lg)
                .stroke(LM.Colors.borderCyan, lineWidth: 1)
        )
        .shadow(color: LM.Colors.cyan.opacity(0.2), radius: 20, x: 0, y: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .padding(.horizontal, LM.Space.md)
    }
}
