import SwiftUI

struct ProfileView: View {
    @ObservedObject var profileService = ProfileService.shared
    @State private var name: String = ""
    @State private var isShowingPricing = false
    @State private var referralInput: String = ""
    @State private var referralApplyError: Bool = false
    @State private var referralApplySuccess: Bool = false
    @State private var showCopiedConfirmation: Bool = false
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
                            Text("Referral bonus active — Lumen Pro free until \(expiry.formatted(date: .abbreviated, time: .omitted))")
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
                                Text("Code applied! Enjoy 30 days of Lumen Pro.")
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

                // MARK: - Subscription
                Section(header: Text("Subscription")) {
                    HStack {
                        Text("Current Plan")
                        Spacer()
                        Text(SubscriptionService.shared.currentTier.title)
                            .foregroundColor(.secondary)
                    }

                    Button("View Plans & Pricing") {
                        isShowingPricing = true
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
        let code = referralService.myCode
        let text = "Try Lumen free for 30 days — use my code \(code) when you first open the app. Download: https://testflight.apple.com/join/5YckE6M7"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
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
