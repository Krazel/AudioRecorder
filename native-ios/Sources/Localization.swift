import Foundation
import SwiftUI

private let appLanguageSelectionKey = "audio.native.selectedLanguage.v1"

enum AppLanguage: String, CaseIterable, Identifiable {
    case ca
    case de
    case en
    case es
    case fr
    case it
    case pt

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .ca: "Català"
        case .de: "Deutsch"
        case .en: "English"
        case .es: "Español"
        case .fr: "Français"
        case .it: "Italiano"
        case .pt: "Português"
        }
    }

    static var initialSelection: AppLanguage {
        if let stored = UserDefaults.standard.string(forKey: appLanguageSelectionKey),
           let language = AppLanguage(rawValue: stored) {
            return language
        }

        for preferredLanguage in Locale.preferredLanguages {
            let code = preferredLanguage
                .replacingOccurrences(of: "_", with: "-")
                .split(separator: "-")
                .first
                .map(String.init)?
                .lowercased()
            if let code, let language = AppLanguage(rawValue: code) {
                return language
            }
        }
        return .en
    }
}

@MainActor
final class AppLanguageStore: ObservableObject {
    @Published var selected: AppLanguage {
        didSet {
            UserDefaults.standard.set(selected.rawValue, forKey: appLanguageSelectionKey)
        }
    }

    init() {
        selected = AppLanguage.initialSelection
    }
}

func L(_ key: String) -> String {
    let language = UserDefaults.standard.string(forKey: appLanguageSelectionKey)
        .flatMap(AppLanguage.init(rawValue:))
        ?? AppLanguage.initialSelection
    let bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj")
        .flatMap(Bundle.init(path:))
        ?? .main
    return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
}
