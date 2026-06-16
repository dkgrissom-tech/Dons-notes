import SwiftUI
import StoreKit

// MARK: - PlansView
struct PlansView: View {
    @ObservedObject var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) var dismiss
    // Pre-reveal bypass panel if owner mode is already active
    @State private var showOwnerBypass = UserDefaults.standard.bool(forKey: "is_owner_bypass")
    @State private var selectedTier: SubscriptionTier = .oraPro
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            gridOverlay

            NavigationView {
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        plansStack
                        purchaseButton
                        restoreButton
                        ownerSection
                        footerNote
                    }
                    .padding(.bottom, 40)
                }
                .background(Color.black)
                .scrollContentBackground(.hidden)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("UPGRADE")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(LM.Colors.cyan)
                            .tracking(4)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(LM.Colors.cyan)
                    }
                }
            }
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreMessage)
        }
        .alert("Purchase Error", isPresented: Binding(
            get: { subscriptionService.purchaseError != nil },
            set: { if !$0 { subscriptionService.purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(subscriptionService.purchaseError ?? "")
        }
    }

    // MARK: - Grid
    private var gridOverlay: some View {
        GeometryReader { geo in
            let cols = Int(geo.size.width / 44) + 1
            let rows = Int(geo.size.height / 44) + 1
            Canvas { ctx, size in
                let cw = size.width / CGFloat(cols)
                let rh = size.height / CGFloat(rows)
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
                ctx.stroke(path, with: .color(LM.Colors.cyan.opacity(0.06)), lineWidth: 0.4)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LM.Colors.cyan.opacity(0.1))
                    .frame(width: 72, height: 72)
                Circle()
                    .stroke(LM.Colors.cyan.opacity(0.4), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundColor(LM.Colors.cyan)
                    .shadow(color: LM.Colors.cyan.opacity(0.8), radius: 8)
            }
            .padding(.top, 24)

            Text("LUMEN PLANS")
                .font(.system(size: 24, weight: .thin, design: .monospaced))
                .foregroundColor(.white)
                .shadow(color: LM.Colors.cyan.opacity(0.4), radius: 8)

            Text("Choose your level of intelligence")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(LM.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }

    // MARK: - Purchase CTA
    @ViewBuilder
    private var purchaseButton: some View {
        let isCurrent = subscriptionService.currentTier == selectedTier
        let isFree = selectedTier == .free
        if !isCurrent && !isFree {
            VStack(spacing: 8) {
                Button {
                    guard let pid = LUMENProductID.allCases.first(where: { $0.tier == selectedTier }) else { return }
                    Task { await subscriptionService.purchase(pid) }
                } label: {
                    ZStack {
                        if subscriptionService.isPurchasing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Subscribe — \(subscriptionService.price(for: LUMENProductID.allCases.first(where: { $0.tier == selectedTier }) ?? .oraPro))")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LM.Colors.cyan)
                    .cornerRadius(LM.Radius.lg)
                }
                .disabled(subscriptionService.isPurchasing || subscriptionService.isLoadingProducts)
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Text("Secure payment via Apple · Cancel anytime")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(LM.Colors.textGhost)
            }
        }
    }

    // MARK: - Restore
    private var restoreButton: some View {
        Button {
            Task {
                await subscriptionService.restorePurchases()
                if subscriptionService.currentTier != .free {
                    restoreMessage = "Your purchases have been restored."
                } else {
                    restoreMessage = "No active purchases found."
                }
                showRestoreAlert = true
            }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(LM.Colors.textGhost)
                .underline()
        }
        .padding(.top, 12)
    }

    // MARK: - Plans
    private var plansStack: some View {
        VStack(spacing: 14) {
            ForEach(SubscriptionTier.allCases) { tier in
                LUMENPlanCard(
                    tier: tier,
                    isCurrent: subscriptionService.currentTier == tier,
                    isSelected: selectedTier == tier
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTier = tier
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Owner
    @ViewBuilder
    private var ownerSection: some View {
        if showOwnerBypass {
            VStack(spacing: 0) {
                ScanLineDivider()
                    .padding(.vertical, 20)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DEMO MODE")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(LM.Colors.cyan)
                            .tracking(2)
                        Text("Owner bypass — internal only")
                            .font(.system(size: 12))
                            .foregroundColor(LM.Colors.textGhost)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { subscriptionService.isOwner },
                        set: { subscriptionService.setOwnerBypass($0) }
                    ))
                    .labelsHidden()
                    .tint(LM.Colors.cyan)
                }
                .padding(16)
                .background(LM.Colors.cyan.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: LM.Radius.lg)
                        .stroke(LM.Colors.cyan.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(LM.Radius.lg)
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Footer
    private var footerNote: some View {
        VStack(spacing: 8) {
            Text("Subscriptions auto-renew. Cancel anytime in Settings.")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(LM.Colors.textGhost.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .onLongPressGesture(minimumDuration: 1.5) {
            withAnimation { showOwnerBypass.toggle() }
        }
    }
}

// MARK: - Plan Card
struct LUMENPlanCard: View {
    let tier: SubscriptionTier
    let isCurrent: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @State private var hovered = false

    private var isHighlighted: Bool { tier.isHighlighted }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(tier.title)
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundColor(isHighlighted ? LM.Colors.cyan : .white)

                            if let badge = tier.badge {
                                Text(badge)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black)
                                    .tracking(1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(LM.Colors.cyan)
                                    .cornerRadius(3)
                            }
                        }

                        if isCurrent {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(LM.Colors.cyan)
                                .tracking(2)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(tier.price)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(isHighlighted ? LM.Colors.cyan : LM.Colors.textPrimary)

                        if tier == .lifetime {
                            Text("one-time")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(LM.Colors.textGhost)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Divider
                Rectangle()
                    .fill(isHighlighted ? LM.Colors.cyan.opacity(0.25) : LM.Colors.borderDim)
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // Features list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(LM.Colors.cyan)
                                .frame(width: 14)

                            Text(feature)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(LM.Colors.textSecondary)

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // CTA
                HStack {
                    Spacer()
                    Text(isCurrent ? "Current Plan" : (isHighlighted ? "Get Ora Pro →" : "Select Plan →"))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(isCurrent ? LM.Colors.textGhost : (isHighlighted ? .black : LM.Colors.cyan))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if isCurrent {
                                    Color.clear
                                } else if isHighlighted {
                                    LM.Colors.cyan
                                } else {
                                    LM.Colors.cyan.opacity(0.1)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isCurrent ? LM.Colors.borderDim : LM.Colors.cyan.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(6)
                    Spacer()
                }
                .padding(.bottom, 16)
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: LM.Radius.lg)
                        .fill(isHighlighted ? LM.Colors.cyan.opacity(0.06) : LM.Colors.surface)
                    RoundedRectangle(cornerRadius: LM.Radius.lg)
                        .stroke(
                            isHighlighted ? LM.Colors.cyan.opacity(0.5) :
                            isSelected ? LM.Colors.cyan.opacity(0.3) :
                            LM.Colors.borderDim,
                            lineWidth: isHighlighted ? 1.5 : 1
                        )
                }
            )
            .shadow(
                color: isHighlighted ? LM.Colors.cyan.opacity(0.12) : .clear,
                radius: 12, x: 0, y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PlansView()
}
