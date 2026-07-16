import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdsService: NSObject, ObservableObject {
    static let shared = AdsService()

    @Published private(set) var canShowAds = false
    @Published private(set) var privacyOptionsRequired = false

    private var hasStartedMobileAds = false
    private var isGatheringConsent = false

    func prepare() {
        guard !isGatheringConsent else { return }
        isGatheringConsent = true

        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }

                if error == nil {
                    do {
                        try await ConsentForm.loadAndPresentIfRequired(from: nil)
                    } catch {
                        // A previous valid consent choice can still allow ads after a form error.
                    }
                }

                self.isGatheringConsent = false
                self.refreshState()
            }
        }
    }

    func presentPrivacyOptions() async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        refreshState()
    }

    private func refreshState() {
        let consent = ConsentInformation.shared
        privacyOptionsRequired = consent.privacyOptionsRequirementStatus == .required
        canShowAds = consent.canRequestAds

        guard canShowAds, !hasStartedMobileAds else { return }
        hasStartedMobileAds = true
        MobileAds.shared.start()
    }
}
