import Foundation

protocol CloudUploading {
    func upload(fileURL: URL) async throws
}

enum CloudUploadError: LocalizedError {
    case providerDisabled
    case authenticationRequired(provider: CloudProvider)

    var errorDescription: String? {
        switch self {
        case .providerDisabled:
            "La subida automatica esta desactivada."
        case .authenticationRequired(let provider):
            "Falta iniciar sesion en \(provider.title)."
        }
    }
}

struct DisabledCloudUploader: CloudUploading {
    func upload(fileURL: URL) async throws {
        throw CloudUploadError.providerDisabled
    }
}

struct GoogleDriveUploader: CloudUploading {
    func upload(fileURL: URL) async throws {
        // Connect GoogleSignIn and Drive API resumable uploads here.
        throw CloudUploadError.authenticationRequired(provider: .googleDrive)
    }
}

struct OneDriveUploader: CloudUploading {
    func upload(fileURL: URL) async throws {
        // Connect MSAL and Microsoft Graph upload sessions here.
        throw CloudUploadError.authenticationRequired(provider: .oneDrive)
    }
}

struct CustomServerUploader: CloudUploading {
    func upload(fileURL: URL) async throws {
        // Send the file to your own backend with URLSession multipart or resumable upload.
        throw CloudUploadError.authenticationRequired(provider: .customServer)
    }
}

enum CloudUploaderFactory {
    static func uploader(for provider: CloudProvider) -> CloudUploading {
        switch provider {
        case .none:
            DisabledCloudUploader()
        case .googleDrive:
            GoogleDriveUploader()
        case .oneDrive:
            OneDriveUploader()
        case .customServer:
            CustomServerUploader()
        }
    }
}
