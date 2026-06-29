import Foundation
import Combine
import AppKit

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

    private var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
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

    /// Checks the lightweight version endpoint. The app never downloads or
    /// installs a package itself; it only exposes the website URL to the user.
    func checkForUpdate(silently: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        if !silently {
            status = .checking
        }
        defer { isChecking = false }

        guard let url = URL(string: versionCheckURL) else {
            if !silently { status = .error("版本检查地址无效") }
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue(currentVersion, forHTTPHeaderField: "X-App-Version")
            request.setValue(currentBuild, forHTTPHeaderField: "X-App-Build")
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if !silently { status = .error("版本服务器暂时不可用") }
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
            if !silently { status = .error("检查更新失败，请稍后重试") }
        }
    }

    func openDownloadPage() {
        guard case .updateAvailable(_, _, let url, _) = status,
              let downloadURL = URL(string: url),
              ["http", "https"].contains(downloadURL.scheme?.lowercased() ?? "") else { return }
        NSWorkspace.shared.open(downloadURL)
    }

    // MARK: - Version Comparison

    private func normalizeVersion(_ version: String) -> [Int] {
        var value = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "v" || value.first == "V" {
            value.removeFirst()
        }
        value = String(value.split(whereSeparator: { $0 == "-" || $0 == "+" }).first ?? "")
        return value.split(separator: ".").map { component in
            Int(component.prefix(while: { $0.isNumber })) ?? 0
        }
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
