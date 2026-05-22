import SwiftUI
import GoogleMobileAds

struct AdMobBannerView: View {
    private let adSize = currentOrientationAnchoredAdaptiveBanner(width: 375)

    var body: some View {
        AdMobBannerContainer(adSize: adSize)
            .frame(width: adSize.size.width, height: adSize.size.height)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .accessibilityLabel("Anuncio")
    }
}

private struct AdMobBannerContainer: UIViewRepresentable {
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AppMonetizationConfig.adMobIOSBannerUnitID
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
