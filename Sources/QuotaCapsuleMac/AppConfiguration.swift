import Foundation

enum ReleaseChannel: String {
    case development
    case internalTest = "internal-test"

    init(rawValue value: String?) {
        switch value?.lowercased() {
        case "development", "dev":
            self = .development
        case "internal-test", "internal_test", "beta", "public":
            self = .internalTest
        default:
            self = .internalTest
        }
    }
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
        let plistChannel = bundle.object(forInfoDictionaryKey: "QuotaCapsuleChannel") as? String
        let channel = ReleaseChannel(rawValue: environment["QUOTA_CAPSULE_CHANNEL"] ?? plistChannel)
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? defaultDisplayName(for: channel)
        let bundleIdentifier = bundle.bundleIdentifier ?? defaultBundleIdentifier(for: channel)
        let plistIssuesURL = bundle.object(forInfoDictionaryKey: "QuotaCapsuleGitHubIssuesURL") as? String

        return AppConfiguration(
            channel: channel,
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            githubIssuesURL: githubIssuesURL(
                channel: channel,
                environment: environment,
                plistValue: plistIssuesURL
            ),
            analyticsEndpointURL: analyticsEndpointURL(channel: channel, environment: environment),
            applicationSupportDirectoryName: applicationSupportDirectoryName(for: channel),
            userDefaultsKeyPrefix: "QuotaCapsule.\(channel.rawValue)"
        )
    }

    func userDefaultsKey(_ name: String) -> String {
        "\(userDefaultsKeyPrefix).\(name).v1"
    }

    private static func githubIssuesURL(
        channel: ReleaseChannel,
        environment: [String: String],
        plistValue: String?
    ) -> URL? {
        let value: String?
        switch channel {
        case .development:
            value = environment["QUOTA_CAPSULE_DEV_GITHUB_ISSUES_URL"]
                ?? plistValue
        case .internalTest:
            value = environment["QUOTA_CAPSULE_PUBLIC_GITHUB_ISSUES_URL"]
                ?? plistValue
                ?? publicGitHubIssuesURL.absoluteString
        }

        guard let value, !value.isEmpty else {
            return nil
        }
        return URL(string: value)
    }

    private static func analyticsEndpointURL(
        channel: ReleaseChannel,
        environment: [String: String]
    ) -> URL? {
        let value: String?
        switch channel {
        case .development:
            value = environment["QUOTA_CAPSULE_DEV_ANALYTICS_ENDPOINT"]
                ?? environment["QUOTA_CAPSULE_ANALYTICS_ENDPOINT"]
        case .internalTest:
            value = environment["QUOTA_CAPSULE_PUBLIC_ANALYTICS_ENDPOINT"]
        }

        guard let value, !value.isEmpty else {
            return nil
        }
        return URL(string: value)
    }

    private static func defaultDisplayName(for channel: ReleaseChannel) -> String {
        switch channel {
        case .development:
            return "Quota Capsule Dev Local"
        case .internalTest:
            return "Quota Capsule Beta"
        }
    }

    private static func defaultBundleIdentifier(for channel: ReleaseChannel) -> String {
        switch channel {
        case .development:
            return "com.bono.quota-capsule.dev"
        case .internalTest:
            return "com.bono.quota-capsule.beta"
        }
    }

    private static func applicationSupportDirectoryName(for channel: ReleaseChannel) -> String {
        switch channel {
        case .development:
            return "Quota Capsule Dev Local"
        case .internalTest:
            return "Quota Capsule Beta"
        }
    }
}
