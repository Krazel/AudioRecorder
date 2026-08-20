import SwiftUI
import GoogleMobileAds
import UIKit

struct AdMobBannerView: View {
    @Binding var isLoaded: Bool
    private let adSize = adSizeFor(cgSize: CGSize(width: 320, height: 50))

    var body: some View {
        AdMobBannerContainer(adSize: adSize) { loaded in
            isLoaded = loaded
        }
            .frame(width: adSize.size.width, height: adSize.size.height)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .clipped()
            .background(Color(.systemBackground))
            .accessibilityLabel(Text(L("Anuncio")))
    }
}

private struct AdMobBannerContainer: UIViewControllerRepresentable {
    let adSize: AdSize
    let onLoadStateChanged: (Bool) -> Void

    func makeUIViewController(context: Context) -> AdMobBannerViewController {
        AdMobBannerViewController(adSize: adSize, onLoadStateChanged: onLoadStateChanged)
    }

    func updateUIViewController(_ uiViewController: AdMobBannerViewController, context: Context) {
        uiViewController.onLoadStateChanged = onLoadStateChanged
    }
}

private final class AdMobBannerViewController: UIViewController, BannerViewDelegate {
    private let bannerView: BannerView
    private var didRequestAd = false
    var onLoadStateChanged: (Bool) -> Void

    init(adSize: AdSize, onLoadStateChanged: @escaping (Bool) -> Void) {
        bannerView = BannerView(adSize: adSize)
        self.onLoadStateChanged = onLoadStateChanged
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        bannerView.adUnitID = AppMonetizationConfig.adMobIOSBannerUnitID
        bannerView.rootViewController = self
        bannerView.delegate = self
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        guard !didRequestAd else { return }
        didRequestAd = true
        bannerView.load(Request())
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        onLoadStateChanged(true)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError _: Error) {
        onLoadStateChanged(false)
    }
}
