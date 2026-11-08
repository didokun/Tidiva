import SwiftUI
import StoreKit

@MainActor final class Membership: ObservableObject {
    static let shared = Membership()
    static let products = ["tidiva.premium.monthly", "tidiva.premium.yearly", "tidiva.premium.lifetime"]
    @Published private(set) var premium: Bool?
    @Published private(set) var activeIDs = Set<String>()
    func refresh() async {
        var active = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.products.contains(transaction.productID),
               transaction.revocationDate == nil, !transaction.isUpgraded { active.insert(transaction.productID) }
        }
        activeIDs = active
        premium = !active.isEmpty
    }
    func observe() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result, Self.products.contains(transaction.productID) {
                await refresh()
                await transaction.finish()
            }
        }
    }
}

struct PremiumOptions: View {
    var onContinue: (() -> Void)? = nil
    @ObservedObject private var membership = Membership.shared
    @State private var catalog: [Product] = []
    @State private var selected = "tidiva.premium.monthly"
    @State private var busy = false
    @State private var message: LocalizedStringKey?
    @State private var loaded = false
    @State private var managing = false
    @State private var trialIDs = Set<String>()
    private var offersTrial: Bool { trialIDs.contains(selected) }

    private var product: Product? { catalog.first { $0.id == selected } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tidiva Premium").font(Theme.headline)
                    VStack(alignment: .leading, spacing: 12) {
                        perk("Ad-free sessions", "sun.max")
                        perk("30-day activity history", "calendar")
                        perk("Activity by room", "house")
                        perk("Export activity as CSV", "square.and.arrow.up")
                    }.panel()
                    if membership.premium == true {
                        Label("Premium is active", systemImage: "checkmark.seal.fill")
                        ForEach(membership.activeIDs.sorted(), id: \.self) { id in
                            LabeledContent("Current plan") {
                                Text(planTitle(id))
                            }
                        }
                        if membership.activeIDs.contains(where: { !$0.hasSuffix("lifetime") }) {
                            Button { managing = true } label: {
                                Label("Change or cancel subscription", systemImage: "slider.horizontal.3")
                            }.buttonStyle(.borderedProminent)
                        }
                    } else {
                        ForEach(Membership.products, id: \.self) { id in
                            planRow(id)
                        }
                        if loaded && catalog.count < Membership.products.count {
                            #if DEBUG
                            Text("For test purchases, run Tidiva from Xcode with Tidiva.storekit selected in the scheme’s Run options.").font(.footnote)
                            #endif
                            Button("Reload prices") { Task { await load() } }
                        }
                        if offersTrial, let product {
                            Text(selected.hasSuffix("monthly") ? "7 days free, then \(product.displayPrice) per month." : "7 days free, then \(product.displayPrice) per year.")
                                .font(.headline)
                        }
                        Text(selected.hasSuffix("lifetime") ? "One payment for lifetime access." : "Renews automatically until canceled.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Restore purchases") { Task { await restore() } }.disabled(busy)
                    }
                    if let message { Text(message).font(.footnote) }
                }.padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 3) {
                if membership.premium != true {
                    PrimaryButton(title: selected.hasSuffix("lifetime") ? "Get lifetime access" : offersTrial ? "Start my 7-day free trial" : "Subscribe to Premium", symbol: "arrow.right") {
                        Task { await buy() }
                    }.disabled(product == nil || busy).opacity(product == nil || busy ? 0.6 : 1)
                }
                if let onContinue {
                    Button(membership.premium == true ? "Done" : "Continue for free", action: onContinue)
                        .font(.subheadline).frame(minHeight: 44).disabled(busy)
                }
            }.padding(.vertical, 6)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await load() }
        .manageSubscriptionsSheet(isPresented: $managing)
        .onChange(of: managing) { _, open in
            if !open { Task { await membership.refresh(); await load() } }
        }
    }

    private func perk(_ title: LocalizedStringKey, _ icon: String) -> some View {
        Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
    }

    private func planTitle(_ id: String) -> LocalizedStringKey {
        if id.hasSuffix("monthly") { return "Monthly" }
        if id.hasSuffix("yearly") { return "Annual" }
        return "Lifetime"
    }

    private func planRow(_ id: String) -> some View {
        let item = catalog.first { $0.id == id }
        let monthly = id.hasSuffix("monthly")
        let title = planTitle(id)
        return Button {
            selected = id
            message = nil
        } label: {
            HStack {
                Image(systemName: selected == id ? "checkmark.circle.fill" : "circle")
                Text(title).font(.headline)
                Spacer()
                if monthly, let item, item.priceFormatStyle.currencyCode == "USD", item.price == 5 {
                    Text(Decimal(10), format: item.priceFormatStyle).strikethrough().foregroundStyle(.secondary)
                }
                if let item { Text(item.displayPrice).font(.title3.bold()) }
                else { Text(loaded ? "Unavailable" : "Loading…").font(.caption) }
            }.padding(16).frame(maxWidth: .infinity)
            .background(selected == id ? Theme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(Theme.leaf.opacity(selected == id ? 1 : 0.25)) }
            .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(item == nil || busy)
        .accessibilityAddTraits(selected == id ? .isSelected : [])
    }

    private func load() async {
        catalog = (try? await Product.products(for: Membership.products)) ?? []
        if product == nil, let first = Membership.products.first(where: { id in catalog.contains { $0.id == id } }) {
            selected = first
        }
        var eligible = Set<String>()
        for item in catalog {
            guard let subscription = item.subscription,
                  let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial,
                  (offer.period.unit == .week && offer.period.value == 1 || offer.period.unit == .day && offer.period.value == 7),
                  offer.periodCount == 1, await subscription.isEligibleForIntroOffer else { continue }
            eligible.insert(item.id)
        }
        trialIDs = eligible
        loaded = true
    }

    private func buy() async {
        guard let product, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await membership.refresh()
                if membership.premium == true { onContinue?() }
            case .userCancelled: break
            case .pending: message = "Purchase pending approval."
            default: message = "Purchase could not be verified."
            }
        } catch { message = "Purchase could not be completed." }
    }

    private func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await membership.refresh()
            if membership.premium != true { message = "No active purchase found." }
        } catch { message = "Couldn’t restore purchases." }
    }
}
