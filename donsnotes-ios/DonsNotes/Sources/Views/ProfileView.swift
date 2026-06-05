import SwiftUI

struct ProfileView: View {
    @ObservedObject var profileService = ProfileService.shared
    @State private var name: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Information")) {
                    TextField("Display Name", text: $name)
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
        }
    }
}
