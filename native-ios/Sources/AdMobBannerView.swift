import SwiftUI
import GoogleMobileAds
import UIKit

struct AdMobBannerView: View {
    private let adSize = adSizeFor(cgSize: CGSize(width: 320, height: 50))

    var body: some View {
        AdMobBannerContainer(adSize: adSize)
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

    func makeUIViewController(context: Context) -> AdMobBannerViewController {
        AdMobBannerViewController(adSize: adSize)
    }

    func updateUIViewController(_ uiViewController: AdMobBannerViewController, context: Context) {}
}

private final class AdMobBannerViewController: UIViewController {
    private let bannerView: BannerView
    private var didRequestAd = false

    init(adSize: AdSize) {
        bannerView = BannerView(adSize: adSize)
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
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRequestAd else { return }
        didRequestAd = true
        bannerView.load(Request())
    }
}
