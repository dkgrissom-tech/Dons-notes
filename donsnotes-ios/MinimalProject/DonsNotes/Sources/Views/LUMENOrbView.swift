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
// Owns a direct @ObservedObject ref to AudioRecorder so it re-renders on every audioLevel tick.
// Uses TimelineView for smooth per-frame time-based animation (no Timer, no withAnimation fights).
struct LUMENOrbView: View {
    let state: LUMENOrbState
    @ObservedObject var recorder: AudioRecorder   // direct subscription — re-renders at 20fps
    var size: CGFloat = 180

    // Trigger flash — the one thing that still needs a brief imperative animation
    @State private var triggerFlash: Double = 0
    @State private var triggerScale: CGFloat = 1.0

    private var coreSize: CGFloat { size * 0.38 }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t   = timeline.date.timeIntervalSinceReferenceDate
            let amp = CGFloat(recorder.audioLevel)   // live — AudioRecorder is @ObservedObject

            canvas(t: t, amp: amp)
        }
        .onChange(of: state) { _, newState in
            guard newState == .triggered else { return }
            triggerFlash = 0.90
            triggerScale = 1.18
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.55)) {
                    triggerFlash = 0
                    triggerScale = 1.0
                }
            }
        }
        .frame(width: size * 1.8, height: size * 1.8)
    }

    // Extracted so TimelineView body is clean
    @ViewBuilder
    private func canvas(t: Double, amp: CGFloat) -> some View {
        // ── Shared math ───────────────────────────────────────────────────
        let breath      = sin(t * 0.75)                        // ~8.4s full cycle
        let breathScale = 1.0 + breath * 0.06
        let breathGlow  = 0.28 + breath * 0.14
        let arcDeg      = (t * 180.0).truncatingRemainder(dividingBy: 360)
        let arcDeg2     = (360 - t * 120.0).truncatingRemainder(dividingBy: 360)

        // ── State-resolved values ─────────────────────────────────────────
        let coreScale:  CGFloat
        let glowOp:     Double
        let r1Op:       Double
        let r2Op:       Double
        let r3Op:       Double
        let r1Scale:    CGFloat
        let r2Scale:    CGFloat
        let r3Scale:    CGFloat
        let ampBoost:   CGFloat

        switch state {
        case .idle:
            coreScale = breathScale
            glowOp    = breathGlow
            r1Op      = 0.38 + breath * 0.16
            r2Op      = 0.18 + breath * 0.10
            r3Op      = 0.08 + breath * 0.06
            r1Scale   = 1.0 + sin(t * 1.1) * 0.03
            r2Scale   = 1.0 + sin(t * 0.85 + 1.0) * 0.025
            r3Scale   = 1.0 + sin(t * 0.65 + 2.0) * 0.018
            ampBoost  = 0

        case .listening:
            coreScale = 1.0 + amp * 0.22
            glowOp    = 0.45 + Double(amp) * 0.55
            r1Op      = 0.50 + Double(amp) * 0.50
            r2Op      = 0.22 + Double(amp) * 0.38
            r3Op      = 0.10 + Double(amp) * 0.20
            // Rings ripple to voice — fast sine adds organic flutter
            r1Scale   = 1.0 + amp * 0.14 + CGFloat(sin(t * 8.0)) * amp * 0.04
            r2Scale   = 1.0 + amp * 0.09 + CGFloat(sin(t * 6.5 + 0.5)) * amp * 0.03
            r3Scale   = 1.0 + amp * 0.05 + CGFloat(sin(t * 5.0 + 1.2)) * amp * 0.02
            ampBoost  = amp * size * 0.28

        case .triggered:
            coreScale = triggerScale
            glowOp    = 0.95
            r1Op      = 1.0; r2Op = 0.72; r3Op = 0.42
            r1Scale   = 1.10; r2Scale = 1.06; r3Scale = 1.03
            ampBoost  = 0

        case .responding:
            let pulse = CGFloat(1.0 + sin(t * 2.5) * 0.04)
            coreScale = pulse
            glowOp    = 0.70 + sin(t * 1.8) * 0.12
            r1Op      = 0.72 + sin(t * 2.1) * 0.18
            r2Op      = 0.38 + sin(t * 1.6) * 0.12
            r3Op      = 0.18 + sin(t * 1.2) * 0.07
            r1Scale   = 1.0 + CGFloat(sin(t * 1.1)) * 0.03
            r2Scale   = 1.0 + CGFloat(sin(t * 0.9 + 1.0)) * 0.025
            r3Scale   = 1.0 + CGFloat(sin(t * 0.7 + 2.0)) * 0.018
            ampBoost  = 0

        case .dormant:
            coreScale = 0.95
            glowOp    = 0.12
            r1Op      = 0.10; r2Op = 0.06; r3Op = 0.03
            r1Scale   = 1.0;  r2Scale = 1.0;  r3Scale = 1.0
            ampBoost  = 0
        }

        ZStack {
            // ── Outer ambient glow ───────────────────────────────────────
            Circle()
                .fill(RadialGradient(
                    colors: [LM.Colors.cyan.opacity(glowOp * 0.55), .clear],
                    center: .center, startRadius: 0, endRadius: size * 0.9
                ))
                .frame(width: size * 1.8, height: size * 1.8)

            // ── Ring 3 (outermost) ───────────────────────────────────────
            Circle()
                .stroke(LM.Colors.cyan.opacity(r3Op), lineWidth: 1)
                .frame(width: size + 60 + ampBoost * 0.55,
                       height: size + 60 + ampBoost * 0.55)
                .scaleEffect(r3Scale)

            // HUD tick marks at 4 cardinal points on ring 3
            ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { angle in
                Rectangle()
                    .fill(LM.Colors.cyan.opacity(r3Op * 1.6))
                    .frame(width: 2, height: 7)
                    .offset(y: -(size * 0.5 + 60 + ampBoost * 0.27 + 3.5))
                    .rotationEffect(.degrees(angle))
                    .scaleEffect(r3Scale)
            }

            // ── Ring 2 (mid) ─────────────────────────────────────────────
            Circle()
                .stroke(LM.Colors.cyan.opacity(r2Op), lineWidth: 1.5)
                .frame(width: size + 30 + ampBoost * 0.38,
                       height: size + 30 + ampBoost * 0.38)
                .scaleEffect(r2Scale)

            // ── Ring 1 (inner) ───────────────────────────────────────────
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [LM.Colors.cyan.opacity(r1Op),
                                 LM.Colors.blue.opacity(r1Op * 0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: size + ampBoost * 0.28,
                       height: size + ampBoost * 0.28)
                .scaleEffect(r1Scale)

            // ── Extra inner glow ring when voice is loud ─────────────────
            if state == .listening && amp > 0.08 {
                Circle()
                    .stroke(LM.Colors.cyanBright.opacity(Double(amp) * 0.85), lineWidth: 3)
                    .frame(width: size * 0.70, height: size * 0.70)
                    .blur(radius: 5)
                    .scaleEffect(r1Scale)
            }

            // ── Responding arcs ──────────────────────────────────────────
            if state == .responding {
                Circle()
                    .trim(from: 0.0, to: 0.35)
                    .stroke(LM.Colors.cyan,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size + 14, height: size + 14)
                    .rotationEffect(.degrees(arcDeg - 90))

                Circle()
                    .trim(from: 0.55, to: 0.75)
                    .stroke(LM.Colors.cyanBright.opacity(0.65),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: size + 24, height: size + 24)
                    .rotationEffect(.degrees(arcDeg2 - 90))
            }

            // ── Core orb ─────────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [
                            LM.Colors.cyanBright.opacity(0.95),
                            LM.Colors.cyan.opacity(0.65),
                            LM.Colors.blue.opacity(0.40),
                            LM.Colors.deep
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: coreSize * 0.9
                    ))
                    .frame(width: coreSize + ampBoost * 0.2,
                           height: coreSize + ampBoost * 0.2)

                // Specular highlight
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.78), .clear],
                        center: .center, startRadius: 0,
                        endRadius: coreSize * 0.3
                    ))
                    .frame(width: coreSize * 0.45, height: coreSize * 0.3)
                    .offset(x: -coreSize * 0.15, y: -coreSize * 0.20)

                Text("LUMEN")
                    .font(LM.Fonts.mono(coreSize * 0.13, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(2)
            }
            .scaleEffect(coreScale)

            // ── Trigger flash ────────────────────────────────────────────
            if triggerFlash > 0 {
                Circle()
                    .fill(Color.white.opacity(triggerFlash))
                    .frame(width: size * 1.5, height: size * 1.5)
            }
        }
    }
}

// MARK: - LUMEN Wave Bar
// Owns nothing heavy — TimelineView + parent's amp passed as let (parent re-renders at 20fps
// because it owns @ObservedObject AudioRecorder, so this gets fresh amp each frame).
struct LUMENWaveBar: View {
    let amplitude: Float
    let index: Int
    let totalBars: Int

    var body: some View {
        TimelineView(.animation) { timeline in
            let t     = timeline.date.timeIntervalSinceReferenceDate
            let amp   = CGFloat(amplitude)
            let phase = Double(index) / Double(totalBars) * .pi * 2.0

            // Idle ripple at zero sound
            let idleH: CGFloat  = 4 + 10 * CGFloat(0.5 + 0.5 * sin(t * 3.5 + phase))
            // Active height: amplitude × per-bar wave variation
            let waveVar         = 0.20 + 0.80 * abs(sin(t * 7.0 + phase))
            let activeH: CGFloat = 4 + 54 * amp * CGFloat(waveVar)

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
// Takes AudioRecorder directly so it re-renders on every audioLevel tick.
struct LUMENWaveformView: View {
    @ObservedObject var recorder: AudioRecorder

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<32, id: \.self) { i in
                LUMENWaveBar(
                    amplitude: recorder.audioLevel,
                    index: i,
                    totalBars: 32
                )
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
