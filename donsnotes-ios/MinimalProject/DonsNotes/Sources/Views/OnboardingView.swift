import SwiftUI

// MARK: - OnboardingView
struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var orbPulse = false
    @State private var orbGlow = false
    @State private var textOpacity: Double = 0
    @State private var scanlineOffset: CGFloat = -300
    @State private var particlesVisible = false
    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0
    @State private var logoOffset: CGFloat = 40
    @State private var logoOpacity: Double = 0

    // MARK: - Referral step state
    @State private var referralCode: String = ""
    @State private var referralApplyError: Bool = false
    @State private var referralApplySuccess: Bool = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Meet LUMEN",
            subtitle: "Your AI meeting intelligence.\nAlways listening. Never missing a word.",
            icon: "circle.hexagongrid.fill",
            accentColor: LM.Colors.cyan
        ),
        OnboardingPage(
            title: "Hey Lumen",
            subtitle: "Ask questions mid-meeting.\nLUMEN answers instantly — voice or silent.",
            icon: "waveform.badge.mic",
            accentColor: LM.Colors.cyan
        ),
        OnboardingPage(
            title: "Every Detail. Captured.",
            subtitle: "Transcription, summaries, action items.\nAll automatically organized.",
            icon: "doc.text.magnifyingglass",
            accentColor: LM.Colors.cyan
        ),
        OnboardingPage(
            title: "Intelligence, Unlocked.",
            subtitle: "Chat with your meeting AI.\nSearch. Analyze. Discover.",
            icon: "brain.head.profile",
            accentColor: LM.Colors.cyan
        )
    ]

    var body: some View {
        ZStack {
            // True black background
            Color.black.ignoresSafeArea()

            // Grid overlay
            GridBackgroundView()
                .opacity(0.08)
                .ignoresSafeArea()

            // Scanline sweep
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, LM.Colors.cyan.opacity(0.04), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 120)
                .offset(y: scanlineOffset)
                .ignoresSafeArea()
                .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: scanlineOffset)

            VStack(spacing: 0) {
                Spacer()

                // Orb display
                ZStack {
                    // Outer ring pulses
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(LM.Colors.cyan.opacity(orbGlow ? 0.15 - Double(i) * 0.04 : 0), lineWidth: 1)
                            .frame(width: CGFloat(160 + i * 40), height: CGFloat(160 + i * 40))
                            .scaleEffect(orbPulse ? 1.0 + CGFloat(i) * 0.05 : 1.0)
                    }

                    // Ping rings
                    Circle()
                        .stroke(LM.Colors.cyan.opacity(ringOpacity), lineWidth: 1.5)
                        .frame(width: 200, height: 200)
                        .scaleEffect(ringScale)

                    // Core orb
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        LM.Colors.cyan.opacity(0.25),
                                        LM.Colors.cyan.opacity(0.08),
                                        Color.black
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 140, height: 140)

                        Circle()
                            .stroke(LM.Colors.cyan.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 140, height: 140)

                        // Inner hex icon
                        Image(systemName: pages[currentPage].icon)
                            .font(.system(size: 44, weight: .ultraLight))
                            .foregroundColor(LM.Colors.cyan)
                            .shadow(color: LM.Colors.cyan.opacity(0.8), radius: 12)
                    }
                    .scaleEffect(orbPulse ? 1.04 : 1.0)
                }
                .frame(height: 260)

                Spacer().frame(height: 48)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        pageContent(for: pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 160)
                .animation(.easeInOut(duration: 0.4), value: currentPage)

                Spacer().frame(height: 32)

                // Page dots (pages + 1 for referral step)
                HStack(spacing: 8) {
                    ForEach(0..<(pages.count + 1), id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? LM.Colors.cyan : LM.Colors.textGhost.opacity(0.4))
                            .frame(width: i == currentPage ? 24 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                Spacer().frame(height: 40)

                // Referral step — shown after the last regular page
                if currentPage == pages.count {
                    referralStepView
                        .padding(.horizontal, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    // CTA button
                    Button(action: handleCTA) {
                        HStack(spacing: 10) {
                            Text(currentPage == pages.count - 1 ? "Activate LUMEN" : "Continue")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(.black)

                            Image(systemName: currentPage == pages.count - 1 ? "bolt.fill" : "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 27)
                                    .fill(LM.Colors.cyan)
                                RoundedRectangle(cornerRadius: 27)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                        )
                        .shadow(color: LM.Colors.cyan.opacity(0.5), radius: 16, x: 0, y: 4)
                    }
                    .padding(.horizontal, 32)
                    .buttonStyle(PlainButtonStyle())

                    // Skip
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundColor(LM.Colors.textGhost)
                        .padding(.top, 16)
                    }
                }

                Spacer().frame(height: 48)
            }
            .padding(.horizontal, 24)
            .opacity(textOpacity)

            // LUMEN logo top
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text("LUMEN")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(LM.Colors.cyan)
                            .tracking(6)
                        Text("v1.2")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundColor(LM.Colors.textGhost)
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 24)
                    .offset(y: logoOffset)
                    .opacity(logoOpacity)
                }
                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: currentPage) { _, _ in
            triggerPageChange()
        }
    }

    // MARK: - Page Content
    @ViewBuilder
    private func pageContent(for page: OnboardingPage) -> some View {
        VStack(spacing: 16) {
            Text(page.title)
                .font(.system(size: 28, weight: .thin, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: LM.Colors.cyan.opacity(0.4), radius: 8)

            Text(page.subtitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(LM.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Referral Step View
    @ViewBuilder
    private var referralStepView: some View {
        VStack(spacing: 20) {
            Text("Got a referral code?")
                .font(.system(size: 24, weight: .thin, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: LM.Colors.cyan.opacity(0.4), radius: 8)

            Text("Enter it below to get 30 days of Lumen Pro free.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(LM.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)

            TextField("Enter code (e.g. ABC123)", text: $referralCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundColor(LM.Colors.cyan)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LM.Colors.cyan.opacity(0.4), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                )
                .onChange(of: referralCode) { _, newValue in
                    referralCode = String(newValue.uppercased().prefix(6))
                    referralApplyError = false
                    referralApplySuccess = false
                }

            if referralApplyError {
                Text("Invalid code — please check and try again.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.red)
            }
            if referralApplySuccess {
                Text("Bonus activated! 30 days of Lumen Pro unlocked.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(LM.Colors.cyan)
            }

            // Apply button
            Button(action: applyOnboardingReferral) {
                Text("Apply Code")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 27).fill(LM.Colors.cyan)
                            RoundedRectangle(cornerRadius: 27).stroke(Color.white.opacity(0.2), lineWidth: 1)
                        }
                    )
                    .shadow(color: LM.Colors.cyan.opacity(0.5), radius: 16, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(referralCode.count != 6)
            .opacity(referralCode.count == 6 ? 1.0 : 0.4)

            // Skip
            Button("Skip") {
                completeOnboarding()
            }
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundColor(LM.Colors.textGhost)
        }
    }

    // MARK: - Actions
    private func handleCTA() {
        if currentPage < pages.count - 1 {
            withAnimation(.spring(response: 0.4)) {
                currentPage += 1
            }
        } else if currentPage == pages.count - 1 {
            // Advance to referral step
            withAnimation(.spring(response: 0.4)) {
                currentPage = pages.count
            }
        } else {
            completeOnboarding()
        }
    }

    private func applyOnboardingReferral() {
        let success = ReferralService.shared.applyReferralCode(referralCode)
        if success {
            referralApplySuccess = true
            referralApplyError = false
            // Brief delay so user sees the confirmation, then complete onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                completeOnboarding()
            }
        } else {
            referralApplyError = true
            referralApplySuccess = false
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeOut(duration: 0.5)) {
            textOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            hasSeenOnboarding = true
        }
    }

    // MARK: - Animations
    private func startAnimations() {
        // Scanline
        scanlineOffset = -300
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scanlineOffset = 800
        }

        // Orb breathing
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            orbPulse = true
        }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            orbGlow = true
        }

        // Ping ring
        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(0.5)) {
            ringScale = 1.8
            ringOpacity = 0
        }

        // Fade in text
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            textOpacity = 1
        }

        // Logo slide in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            logoOffset = 0
            logoOpacity = 1
        }
    }

    private func triggerPageChange() {
        // Flash ring on page change
        ringScale = 0.3
        ringOpacity = 0.6
        withAnimation(.easeOut(duration: 1.2)) {
            ringScale = 1.8
            ringOpacity = 0
        }
    }
}

// MARK: - Supporting Types
private struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
}

// MARK: - Grid Background (reused from MeetingListView if needed)
private struct GridBackgroundView: View {
    var body: some View {
        GeometryReader { geo in
            let cols = Int(geo.size.width / 44) + 1
            let rows = Int(geo.size.height / 44) + 1
            Canvas { ctx, size in
                let cw: CGFloat = size.width / CGFloat(cols)
                let rh: CGFloat = size.height / CGFloat(rows)
                var path = Path()
                for c in 0...cols {
                    let x = CGFloat(c) * cw
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for r in 0...rows {
                    let y = CGFloat(r) * rh
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(path, with: .color(LM.Colors.cyan), lineWidth: 0.4)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
