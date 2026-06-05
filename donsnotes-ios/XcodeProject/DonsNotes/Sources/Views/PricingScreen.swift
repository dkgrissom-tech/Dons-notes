import SwiftUI

struct PricingScreen: View {
    @ObservedObject var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) var dismiss
    @State private var showOwnerBypass = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Choose Your Plan")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top)
                        .onLongPressGesture(minimumDuration: 3) {
                            showOwnerBypass.toggle()
                        }
                    
                    Text("Don's Notes helps you capture every meeting detail with ease.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    ForEach(SubscriptionTier.allCases) { tier in
                        PlanCard(tier: tier, isCurrent: subscriptionService.currentTier == tier) {
                            // Buttons show "Coming Soon" for non-current tiers
                        }
                    }
                    
                    if showOwnerBypass {
                        ownerSection
                            .padding(.top)
                    }
                    
                    Text("Payment integration coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var ownerSection: some View {
        VStack {
            Divider()
            HStack {
                Text("Demo Mode (Owner)")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { subscriptionService.isOwner },
                    set: { subscriptionService.setOwnerBypass($0) }
                ))
                .labelsHidden()
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(10)
            
            Text("Internal use only. Bypasses all limits.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct PlanCard: View {
    let tier: SubscriptionTier
    let isCurrent: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tier.title)
                    .font(.title2)
                    .bold()
                Spacer()
                Text(tier.price)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .bold()
            }
            
            Text(tier.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            if isCurrent {
                Text("Current Plan")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            } else {
                Button(action: action) {
                    Text("Coming Soon")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isCurrent ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    PricingScreen()
}
