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
        } catch { preparing = false }
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

struct AdvertisingSlot: View {
    @ObservedObject private var membership = Membership.shared
    @ObservedObject private var consent = AdConsent.shared
    @AppStorage("tidiva.profile.age") private var age = 0
    var body: some View {
        if membership.premium == false, age == 0 || age >= 18,
           let unit = Bundle.main.object(forInfoDictionaryKey: "TidivaBannerID") as? String, !unit.isEmpty {
            VStack {
                if consent.ready {
                    Banner(unit: unit).frame(width: 320, height: 50)
                }
            }.frame(maxWidth: .infinity).task { await consent.prepare() }
        }
    }

    private struct Banner: UIViewRepresentable {
        let unit: String
        func makeUIView(context: Context) -> BannerView {
            let view = BannerView(adSize: AdSizeBanner)
            view.adUnitID = unit
            view.load(Request())
            return view
        }
        func updateUIView(_ view: BannerView, context: Context) {}
    }
}
