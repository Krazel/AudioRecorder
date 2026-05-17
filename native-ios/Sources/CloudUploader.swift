import Foundation

protocol CloudUploading {
    func upload(fileURL: URL) async throws
}

enum CloudUploadError: LocalizedError {
    case providerDisabled
    case authenticationRequired(provider: CloudProvider)
    case missingEndpoint
    case invalidServerResponse(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .providerDisabled:
            "La subida automatica esta desactivada."
        case .authenticationRequired(let provider):
            "Falta iniciar sesion en \(provider.title)."
        case .missingEndpoint:
            "Falta configurar la URL de subida del servidor propio."
        case .invalidServerResponse(let statusCode):
            "El servidor rechazo la subida con codigo \(statusCode)."
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
    let endpoint: URL?
    let recordingID: UUID

    func upload(fileURL: URL) async throws {
        guard let endpoint else {
            throw CloudUploadError.missingEndpoint
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try multipartBody(
            boundary: boundary,
            fileURL: fileURL,
            recordingID: recordingID
        )
        let (_, response) = try await URLSession.shared.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CloudUploadError.invalidServerResponse(statusCode: statusCode)
        }
    }

    private func multipartBody(
        boundary: String,
        fileURL: URL,
        recordingID: UUID
    ) throws -> Data {
        var data = Data()
        appendField(name: "recording_id", value: recordingID.uuidString, boundary: boundary, to: &data)
        appendField(name: "provider", value: CloudProvider.customServer.rawValue, boundary: boundary, to: &data)

        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        data.append("Content-Type: audio/mp4\r\n\r\n")
        data.append(try Data(contentsOf: fileURL))
        data.append("\r\n--\(boundary)--\r\n")
        return data
    }

    private func appendField(name: String, value: String, boundary: String, to data: inout Data) {
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        data.append("\(value)\r\n")
    }
}

enum CloudUploaderFactory {
    static func uploader(for job: UploadJob) -> CloudUploading {
        switch job.provider {
        case .none:
            DisabledCloudUploader()
        case .googleDrive:
            GoogleDriveUploader()
        case .oneDrive:
            OneDriveUploader()
        case .customServer:
            CustomServerUploader(endpoint: job.endpointURL, recordingID: job.recordingID)
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
