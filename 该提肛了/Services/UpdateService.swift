import Foundation

// MARK: - Update API Types

struct AppVersionResponse: Codable {
    let latestVersion: String
    let minRequiredVersion: String
    let downloadURL: String
    let releaseNotes: String
    let forceUpdate: Bool

    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case minRequiredVersion = "min_required_version"
        case downloadURL = "download_url"
        case releaseNotes = "release_notes"
        case forceUpdate = "force_update"
    }
}

// MARK: - Update Status

enum UpdateStatus: Equatable {
    case unknown
    case checking
    case upToDate
    case updateAvailable(version: String, notes: String, downloadURL: String, forceRequired: Bool)
    case error(String)
    case downloading
    case downloaded
}

// MARK: - Update Service

@MainActor
final class UpdateService: ObservableObject {
    @Published var status: UpdateStatus = .unknown
    @Published var isChecking = false

    private let session: URLSession
    private let versionCheckURL: String

    init(baseURL: String) {
        self.versionCheckURL = "\(baseURL)/app/version"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var hasUpdate: Bool {
        if case .updateAvailable = status { return true }
        return false
    }

    var isForceRequired: Bool {
        if case .updateAvailable(_, _, _, let force) = status { return force }
        return false
    }

    var latestVersion: String? {
        if case .updateAvailable(let version, _, _, _) = status { return version }
        return nil
    }

    func checkForUpdate() async {
        guard !isChecking else { return }
        isChecking = true
        status = .checking

        guard let url = URL(string: versionCheckURL) else {
            status = .error("Invalid URL")
            isChecking = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                status = .error("Network error")
                isChecking = false
                return
            }

            let decoded = try JSONDecoder().decode(AppVersionResponse.self, from: data)

            let current = normalizeVersion(currentVersion)
            let latest = normalizeVersion(decoded.latestVersion)
            let minRequired = normalizeVersion(decoded.minRequiredVersion)

            if compareVersions(current, isLessThan: minRequired) {
                status = .updateAvailable(
                    version: decoded.latestVersion,
                    notes: decoded.releaseNotes,
                    downloadURL: decoded.downloadURL,
                    forceRequired: true
                )
            } else if compareVersions(current, isLessThan: latest) {
                status = .updateAvailable(
                    version: decoded.latestVersion,
                    notes: decoded.releaseNotes,
                    downloadURL: decoded.downloadURL,
                    forceRequired: decoded.forceUpdate
                )
            } else {
                status = .upToDate
            }
        } catch {
            status = .error("检查更新失败")
        }

        isChecking = false
    }

    func openDownloadPage() {
        guard case .updateAvailable(_, _, let url, _) = status,
              let downloadURL = URL(string: url) else { return }
        NSWorkspace.shared.open(downloadURL)
    }

    // MARK: - Version Comparison

    private func normalizeVersion(_ version: String) -> [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }

    private func compareVersions(_ lhs: [Int], isLessThan rhs: [Int]) -> Bool {
        let maxCount = max(lhs.count, rhs.count)
        for i in 0..<maxCount {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l < r { return true }
            if l > r { return false }
        }
        return false
    }
}
