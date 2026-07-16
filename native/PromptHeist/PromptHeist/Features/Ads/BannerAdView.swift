import GoogleMobileAds
import SwiftUI

struct BannerAdView: View {
    @EnvironmentObject private var ads: AdsService

    var body: some View {
        if ads.canShowAds {
            BannerViewContainer()
                .frame(width: 320, height: 50)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .accessibilityLabel("Advertisement")
        }
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let size = adSizeFor(cgSize: CGSize(width: 320, height: 50))
        let banner = BannerView(adSize: size)
        banner.adUnitID = Self.adUnitID
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {}

    private static var adUnitID: String {
#if DEBUG
        "ca-app-pub-3940256099942544/2435281174"
#else
        "ca-app-pub-8193336706637140/1849794949"
#endif
    }
}
