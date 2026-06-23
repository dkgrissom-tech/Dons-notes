import SwiftUI

struct ProfileView: View {
    @ObservedObject var profileService = ProfileService.shared
    @ObservedObject var subscriptionService = SubscriptionService.shared
    @State private var name: String = ""
    @State private var isShowingPricing = false
    @State private var referralInput: String = ""
    @State private var referralApplyError: Bool = false
    @State private var referralApplySuccess: Bool = false
    @State private var showCopiedConfirmation: Bool = false
    @State private var devTapCount: Int = 0
    @State private var isShowingShareSheet = false
    @State private var todayChat: Int = 0
    @State private var todayTrans: Int = 0
    @Environment(\.dismiss) var dismiss

    private var referralService: ReferralService { ReferralService.shared }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Information")) {
                    TextField("Display Name", text: $name)
                }

                // MARK: - Refer a Friend
                Section(header: Text("Refer a Friend")) {
                    // User's own code + copy button
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your referral code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(referralService.myCode)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        Button(action: copyCode) {
                            Label(showCopiedConfirmation ? "Copied!" : "Copy",
                                  systemImage: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(showCopiedConfirmation ? .green : .cyan)
                        .animation(.easeInOut(duration: 0.2), value: showCopiedConfirmation)
                    }

                    Text("Give a friend 30 days free. You get 30 days free too.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Share button
                    Button(action: shareCode) {
                        Label("Share your code", systemImage: "square.and.arrow.up")
                    }

                    // Referral bonus status
                    if referralService.hasReferralBonus,
                       let expiry = referralService.referralProExpiryDate {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.cyan)
                            Text("Referral bonus active — Ora Pro free until \(expiry.formatted(date: .abbreviated, time: .omitted))")
                                .foregroundColor(.cyan)
                                .font(.footnote)
                        }
                    }

                    // Code entry (only shown if no code has been applied yet)
                    if !referralService.hasAppliedCode {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Have a referral code? Enter it here", text: $referralInput)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: referralInput) { _, newValue in
                                    referralInput = String(newValue.uppercased().prefix(6))
                                    referralApplyError = false
                                    referralApplySuccess = false
                                }

                            if referralApplyError {
                                Text("Invalid code. Please check and try again.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if referralApplySuccess {
                                Text("Code applied! Enjoy 30 days of Ora Pro.")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }

                            Button("Apply") {
                                applyCode()
                            }
                            .disabled(referralInput.count != 6)
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                        }
                    }
                }

                // MARK: - Ora Usage (Groq free-tier telemetry)
                Section(header: Text("Ora Usage")) {
                    HStack {
                        Text("Chat calls today")
                        Spacer()
                        Text("\(todayChat)").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Transcriptions today")
                        Spacer()
                        Text("\(todayTrans)").foregroundColor(.secondary)
                    }
                    Text("Free tier resets daily. Limits: ~14,400 chat / 7,200 transcription.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - Subscription
                Section(header: Text("Subscription")) {
                    HStack {
                        Text("Current Plan")
                        Spacer()
                        Text(subscriptionService.isOwner ? "Ora Pro (Dev)" : subscriptionService.currentTier.title)
                            .foregroundColor(subscriptionService.isOwner ? .cyan : .secondary)
                    }

                    Button("View Plans & Pricing") {
                        isShowingPricing = true
                    }
                }

                // MARK: - Developer Access (hidden — tap header 5x to reveal)
                Section(header:
                    Text(devTapCount >= 5 ? "Developer Access" : " ")
                        .onTapGesture {
                            devTapCount += 1
                        }
                ) {
                    if devTapCount >= 5 {
                        Toggle(isOn: Binding(
                            get: { subscriptionService.isOwner },
                            set: { subscriptionService.setOwnerBypass($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Full Access Override")
                                    .font(.subheadline)
                                Text("Unlocks all Ora Pro features for testing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.cyan)
                    }
                }

                Section {
                    Button("Save") {
                        profileService.saveName(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Profile Settings")
            .onAppear {
                self.name = profileService.userName
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingPricing) {
                PlansView()
            }
            .sheet(isPresented: $isShowingShareSheet) {
                let code = referralService.myCode
                let text = "Try Ora free for 30 days — use my code \(code) when you first open the app. Download: https://testflight.apple.com/join/5YckE6M7"
                ShareSheet(items: [text])
            }
        }
        .task {
            let counts = await GroqUsageTracker.shared.todayCounts()
            todayChat = counts.chat
            todayTrans = counts.transcription
        }
    }

    // MARK: - Actions
    private func copyCode() {
        UIPasteboard.general.string = referralService.myCode
        showCopiedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedConfirmation = false
        }
    }

    private func shareCode() {
        // iOS 18 crash-proof: show via SwiftUI sheet instead of presenting on rootViewController
        isShowingShareSheet = true
    }

    private func applyCode() {
        let success = referralService.applyReferralCode(referralInput)
        if success {
            referralApplySuccess = true
            referralApplyError = false
            referralInput = ""
        } else {
            referralApplyError = true
            referralApplySuccess = false
        }
    }
}
