import SwiftUI

// MARK: - OnboardingView
// Deliberately minimal — no async tasks, no animation timers, no repeatForever.
// The only state change that matters is hasSeenOnboarding = true, set synchronously.
struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    // Referral step
    @State private var referralCode = ""
    @State private var referralError = false
    @State private var referralSuccess = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(title: "Meet ORA",
                       subtitle: "Your AI meeting intelligence.\nAlways listening. Never missing a word.",
                       icon: "circle.hexagongrid.fill"),
        OnboardingPage(title: "Just say Ora",
                       subtitle: "Ask questions mid-meeting.\nORA answers instantly — voice or silent.",
                       icon: "waveform.badge.mic"),
        OnboardingPage(title: "Every Detail. Captured.",
                       subtitle: "Transcription, summaries, action items.\nAll automatically organized.",
                       icon: "doc.text.magnifyingglass"),
        OnboardingPage(title: "Intelligence, Unlocked.",
                       subtitle: "Chat with your meeting AI.\nSearch. Analyze. Discover.",
                       icon: "brain.head.profile")
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Orb — static, no animation state
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [LM.Colors.cyan.opacity(0.3), LM.Colors.cyan.opacity(0.05), Color.black],
                            center: .center, startRadius: 10, endRadius: 70))
                        .frame(width: 140, height: 140)
                    Circle()
                        .stroke(LM.Colors.cyan.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 140, height: 140)
                    Image(systemName: currentPage < pages.count ? pages[currentPage].icon : "checkmark")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundColor(LM.Colors.cyan)
                        .shadow(color: LM.Colors.cyan.opacity(0.8), radius: 12)
                }
                .frame(height: 180)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                Spacer().frame(height: 48)

                // Page content or referral step
                if currentPage < pages.count {
                    VStack(spacing: 16) {
                        Text(pages[currentPage].title)
                            .font(.system(size: 28, weight: .thin, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text(pages[currentPage].subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(LM.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                    }
                    .padding(.horizontal, 32)
                    .frame(height: 140)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                } else {
                    // Referral step
                    VStack(spacing: 20) {
                        Text("Got a referral code?")
                            .font(.system(size: 24, weight: .thin, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("Enter it below for 30 days of Ora Pro free.")
                            .font(.system(size: 15))
                            .foregroundColor(LM.Colors.textSecondary)
                            .multilineTextAlignment(.center)

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
                            )
                            .onChange(of: referralCode) { _, v in
                                referralCode = String(v.uppercased().prefix(6))
                                referralError = false; referralSuccess = false
                            }

                        if referralError {
                            Text("Invalid code — please check and try again.")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        if referralSuccess {
                            Text("30 days of Ora Pro unlocked!")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(LM.Colors.cyan)
                        }

                        Button("Apply Code") {
                            if ReferralService.shared.applyReferralCode(referralCode) {
                                referralSuccess = true
                            } else {
                                referralError = true
                            }
                        }
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(LM.Colors.cyan)
                        .cornerRadius(27)
                        .disabled(referralCode.count != 6)
                        .opacity(referralCode.count == 6 ? 1.0 : 0.4)
                        .padding(.horizontal, 32)
                    }
                    .padding(.horizontal, 32)
                    .frame(height: 140)
                }

                Spacer().frame(height: 32)

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<(pages.count + 1), id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? LM.Colors.cyan : Color.white.opacity(0.2))
                            .frame(width: i == currentPage ? 24 : 6, height: 6)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: currentPage)

                Spacer().frame(height: 40)

                // CTA button
                Button(action: handleNext) {
                    HStack(spacing: 10) {
                        Text(buttonLabel)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.black)
                        Image(systemName: currentPage >= pages.count ? "checkmark" : "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(LM.Colors.cyan)
                    .cornerRadius(27)
                    .shadow(color: LM.Colors.cyan.opacity(0.4), radius: 12)
                }
                .padding(.horizontal, 32)
                .buttonStyle(PlainButtonStyle())

                // Skip button
                if currentPage < pages.count - 1 {
                    Button("Skip") { finish() }
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.3))
                        .padding(.top, 16)
                }

                Spacer().frame(height: 48)
            }

            // ORA label top-right
            VStack {
                HStack {
                    Spacer()
                    Text("ORA")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(LM.Colors.cyan)
                        .tracking(6)
                        .padding(.top, 60)
                        .padding(.trailing, 24)
                }
                Spacer()
            }
        }
    }

    private var buttonLabel: String {
        if currentPage < pages.count - 1 { return "Continue" }
        if currentPage == pages.count - 1 { return "Activate ORA" }
        return "Get Started"
    }

    private func handleNext() {
        if currentPage < pages.count {
            withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
        } else {
            finish()
        }
    }

    // Synchronous — no async, no timers, no DispatchQueue. Impossible to crash.
    private func finish() {
        hasSeenOnboarding = true
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
}

#Preview {
    OnboardingView()
}
