import Foundation

enum ReleaseChannel: String {
    case beta
}

struct AppConfiguration {
    static let publicGitHubIssuesURL = URL(string: "https://github.com/Bono12138/codex-quota-capsule/issues")!

    let channel: ReleaseChannel
    let displayName: String
    let bundleIdentifier: String
    let githubIssuesURL: URL?
    let analyticsEndpointURL: URL?
    let applicationSupportDirectoryName: String
    let userDefaultsKeyPrefix: String

    static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> AppConfiguration {
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "Quota Capsule Beta"
        let bundleIdentifier = bundle.bundleIdentifier ?? "com.bono.quota-capsule.beta"
        let plistIssuesURL = bundle.object(forInfoDictionaryKey: "QuotaCapsuleGitHubIssuesURL") as? String
        let issuesValue = environment["QUOTA_CAPSULE_PUBLIC_GITHUB_ISSUES_URL"]
            ?? plistIssuesURL
            ?? publicGitHubIssuesURL.absoluteString
        let analyticsValue = environment["QUOTA_CAPSULE_PUBLIC_ANALYTICS_ENDPOINT"]

        return AppConfiguration(
            channel: .beta,
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            githubIssuesURL: URL(string: issuesValue),
            analyticsEndpointURL: analyticsValue.flatMap { URL(string: $0) },
            applicationSupportDirectoryName: "Quota Capsule Beta",
            userDefaultsKeyPrefix: "QuotaCapsule.beta"
        )
    }

    func userDefaultsKey(_ name: String) -> String {
        "\(userDefaultsKeyPrefix).\(name).v1"
    }
}
