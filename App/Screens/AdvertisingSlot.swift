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

// One separated, fixed-size banner per browsing screen. No requests while
// Premium status is unknown, for under-18 profiles, or without consent.
private struct BrowsingBanner: View {
    @ObservedObject private var membership = Membership.shared
    @ObservedObject private var consent = AdConsent.shared
    @AppStorage("tidiva.profile.age") private var age = 0
    @State private var loaded = false

    private var eligible: Bool {
        membership.premium == false && (age == 0 || age >= 18)
    }
    private var unit: String {
        Bundle.main.object(forInfoDictionaryKey: "TidivaBannerID") as? String ?? ""
    }

    var body: some View {
        Group {
            if eligible && consent.ready && ConsentInformation.shared.canRequestAds && !unit.isEmpty {
                VStack(spacing: 4) {
                    Text("Advertisement").font(.caption2).foregroundStyle(.secondary)
                    BannerContainer(unit: unit, loaded: $loaded)
                        .frame(width: 320, height: 50)
                }
                .padding(.vertical, loaded ? 10 : 0)
                .frame(maxWidth: .infinity)
                .frame(height: loaded ? 82 : 0)
                .clipped()
                .allowsHitTesting(loaded)
                .background(Theme.paper)
            }
        }
        .task(id: eligible) {
            if eligible && !unit.isEmpty { await consent.prepare() }
        }
    }
}

private struct BannerContainer: UIViewRepresentable {
    let unit: String
    @Binding var loaded: Bool

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = unit
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, BannerViewDelegate {
        var parent: BannerContainer
        init(parent: BannerContainer) { self.parent = parent }
        func bannerViewDidReceiveAd(_ bannerView: BannerView) { parent.loaded = true }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            parent.loaded = false
        }
    }
}

extension View {
    func browsingAdvertising() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { BrowsingBanner() }
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
