import SwiftUI

struct ProfileView: View {
    @ObservedObject var profileService = ProfileService.shared
    @State private var name: String = ""
    @State private var isShowingPricing = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Information")) {
                    TextField("Display Name", text: $name)
                }
                
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
}
