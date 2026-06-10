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

    @State private var idlePulse: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.4
    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring3Scale: CGFloat = 1.0
    @State private var ring1Opacity: Double = 0.5
    @State private var ring2Opacity: Double = 0.3
    @State private var ring3Opacity: Double = 0.15
    @State private var arcRotation: Double = 0
    @State private var triggerFlash: Double = 0
    @State private var particleOpacity: Double = 0.6

    private var coreSize: CGFloat { size * 0.38 }
    private var ampBoost: CGFloat { CGFloat(amplitude) * size * 0.25 }

    var body: some View {
        ZStack {
            // Outer ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [LM.Colors.cyan.opacity(glowOpacity * 0.6), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.9
                    )
                )
                .frame(width: size * 1.8, height: size * 1.8)

            // Ring 3 — outermost, slow
            Circle()
                .stroke(LM.Colors.cyan.opacity(ring3Opacity), lineWidth: 1)
                .frame(width: size + 60 + ampBoost * 0.6, height: size + 60 + ampBoost * 0.6)
                .scaleEffect(ring3Scale)

            // Ring 2 — mid
            Circle()
                .stroke(LM.Colors.cyan.opacity(ring2Opacity), lineWidth: 1.5)
                .frame(width: size + 30 + ampBoost * 0.4, height: size + 30 + ampBoost * 0.4)
                .scaleEffect(ring2Scale)

            // Ring 1 — inner glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [LM.Colors.cyan.opacity(ring1Opacity), LM.Colors.blue.opacity(ring1Opacity * 0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: size + ampBoost * 0.3, height: size + ampBoost * 0.3)
                .scaleEffect(ring1Scale)

            // Rotating arc (responding state)
            if state == .responding {
                Circle()
                    .trim(from: 0.0, to: 0.35)
                    .stroke(LM.Colors.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size + 14, height: size + 14)
                    .rotationEffect(.degrees(arcRotation))
                Circle()
                    .trim(from: 0.55, to: 0.75)
                    .stroke(LM.Colors.cyanBright.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: size + 22, height: size + 22)
                    .rotationEffect(.degrees(-arcRotation * 0.7))
            }

            // Core orb
            ZStack {
                // Base glow fill
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
                    .frame(width: coreSize + ampBoost * 0.2, height: coreSize + ampBoost * 0.2)

                // Inner specular highlight
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

                // LUMEN text inside orb (subtle)
                Text("LUMEN")
                    .font(LM.Fonts.mono(coreSize * 0.13, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2)
            }
            .scaleEffect(idlePulse)

            // Trigger flash overlay
            if triggerFlash > 0 {
                Circle()
                    .fill(Color.white.opacity(triggerFlash))
                    .frame(width: size * 1.5, height: size * 1.5)
            }
        }
        .onAppear { startAnimations() }
        .onChange(of: state) { _, newState in handleStateChange(newState) }
        .onChange(of: amplitude) { _, _ in updateAmplitude() }
        .frame(width: size * 1.8, height: size * 1.8)
    }

    private func startAnimations() {
        handleStateChange(state)
    }

    private func handleStateChange(_ newState: LUMENOrbState) {
        switch newState {
        case .idle:
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                idlePulse = 1.06
                glowOpacity = 0.35
                ring1Scale = 1.04
                ring2Scale = 1.03
                ring3Scale = 1.02
                ring1Opacity = 0.4
                ring2Opacity = 0.2
                ring3Opacity = 0.10
            }

        case .listening:
            // Amplitude will drive the animation
            withAnimation(.easeInOut(duration: 0.3)) {
                glowOpacity = 0.6
                ring1Opacity = 0.7
                ring2Opacity = 0.4
                ring3Opacity = 0.2
            }

        case .triggered:
            // Flash white then settle
            withAnimation(.easeOut(duration: 0.15)) {
                triggerFlash = 0.85
                idlePulse = 1.15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.6)) {
                    triggerFlash = 0
                    idlePulse = 1.0
                    glowOpacity = 0.9
                    ring1Opacity = 1.0
                    ring2Opacity = 0.6
                }
            }

        case .responding:
            withAnimation(.easeInOut(duration: 0.3)) {
                glowOpacity = 0.8
                ring1Opacity = 0.8
            }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                arcRotation = 360
            }

        case .dormant:
            withAnimation(.easeOut(duration: 1.0)) {
                idlePulse = 1.0
                glowOpacity = 0.15
                ring1Opacity = 0.15
                ring2Opacity = 0.08
                ring3Opacity = 0.04
            }
        }
    }

    private func updateAmplitude() {
        guard state == .listening else { return }
        let boost = CGFloat(amplitude)
        withAnimation(.easeOut(duration: 0.08)) {
            idlePulse = 1.0 + boost * 0.18
            glowOpacity = 0.5 + Double(boost) * 0.5
        }
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
        .overlay(RoundedRectangle(cornerRadius: LM.Radius.lg).stroke(LM.Colors.borderCyan, lineWidth: 1))
        .shadow(color: LM.Colors.cyan.opacity(0.2), radius: 20, x: 0, y: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .padding(.horizontal, LM.Space.md)
    }
}
