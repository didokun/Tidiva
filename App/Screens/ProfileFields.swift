import AuthenticationServices
import SwiftUI

struct ProfileFields: View {
    @AppStorage("tidiva.profile.lastName") private var lastName = ""
    @AppStorage("tidiva.profile.age") private var age = 0
    @Environment(\.colorScheme) private var scheme
    @AppStorage("tidiva.profile.name") private var name = ""
    @AppStorage("tidiva.profile.email") private var email = ""
    @AppStorage("tidiva.profile.appleUser") private var user = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            nameCard("First name (optional)", icon: "person", text: $name, type: .givenName)
            nameCard("Last name (optional)", icon: "person.text.rectangle", text: $lastName, type: .familyName)
            HStack {
                Label("Age (optional)", systemImage: "calendar")
                Spacer()
                Picker("Age (optional)", selection: $age) {
                    Text("Prefer not to say").tag(0)
                    ForEach(1...120, id: \.self) { Text($0, format: .number).tag($0) }
                }.labelsHidden()
            }.padding(18).background(Theme.mint, in: RoundedRectangle(cornerRadius: 20))
            if !email.isEmpty {
                Label(email, systemImage: "envelope").font(.subheadline)
            }
            #if TIDIVA_APPLE_SIGN_IN
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                        errorMessage = "Apple couldn’t share your profile."
                        return
                    }
                    let sharedName = credential.fullName?.givenName ?? ""
                    let switched = !user.isEmpty && user != credential.user
                    if switched || !sharedName.isEmpty { name = sharedName }
                    if switched || credential.fullName?.familyName != nil { lastName = credential.fullName?.familyName ?? "" }
                    if switched { age = 0 }
                    if switched || credential.email != nil { email = credential.email ?? "" }
                    user = credential.user
                    errorMessage = nil
                case .failure(let error):
                    if (error as? ASAuthorizationError)?.code != .canceled {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
            .frame(height: 48)
            #endif
            if !user.isEmpty {
                Button("Remove local profile", role: .destructive) {
                    name = ""
                    lastName = ""
                    age = 0
                    email = ""
                    user = ""
                }
            }
            if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.secondary) }
        }
    }
    private func nameCard(_ title: LocalizedStringKey, icon: String, text: Binding<String>, type: UITextContentType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            TextField(title, text: text, prompt: Text(title).foregroundColor(Theme.ink.opacity(0.65)))
                .textContentType(type).textInputAutocapitalization(.words)
                .textFieldStyle(.plain).font(.title3).foregroundStyle(Theme.ink).tint(Theme.ink)
                .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 58)
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(Theme.leaf.opacity(0.5)).allowsHitTesting(false) }
        }.padding(.vertical, 6)
    }

}
