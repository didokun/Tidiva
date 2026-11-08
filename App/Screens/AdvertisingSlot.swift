import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

@MainActor private final class AdConsent: ObservableObject {
    static let shared = AdConsent()
    @Published var ready = false
    @Published var needsOptions = false
    private var preparing = false
    func prepare() async {
        guard !preparing else { return }
        preparing = true
        do {
            let info = ConsentInformation.shared
            try await info.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
            needsOptions = info.privacyOptionsRequirementStatus == .required
            if info.canRequestAds {
                _ = await MobileAds.shared.start()
                ready = true
            }
        } catch { ready = false }
        preparing = false
    }
}

struct AdvertisingPrivacyOptions: View {
    @ObservedObject private var consent = AdConsent.shared
    @State private var failed = false
    var body: some View {
        if consent.needsOptions {
            Button("Advertising privacy choices") {
                Task {
                    do {
                        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
                        consent.ready = ConsentInformation.shared.canRequestAds
                    } catch { failed = true }
                }
            }.alert("Couldn’t open privacy choices", isPresented: $failed) { Button("OK") {} }
        }
    }
}

@MainActor final class SessionAdvertising: ObservableObject {
    private var ad: InterstitialAd?
    private var eligible: Bool {
        let age = UserDefaults.standard.integer(forKey: "tidiva.profile.age")
        return Membership.shared.premium == false && (age == 0 || age >= 18)
    }

    func preload() async {
        guard eligible, let unit = Bundle.main.object(forInfoDictionaryKey: "TidivaInterstitialID") as? String,
              !unit.isEmpty else { return }
        await AdConsent.shared.prepare()
        guard AdConsent.shared.ready, eligible else { return }
        ad = try? await InterstitialAd.load(with: unit, request: Request())
    }

    func showAtCompletion() {
        guard eligible, ConsentInformation.shared.canRequestAds, let loaded = ad else { return }
        ad = nil
        loaded.present(from: nil)
    }
}
