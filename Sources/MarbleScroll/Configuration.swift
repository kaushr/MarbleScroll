import Foundation
#if SWIFT_PACKAGE
import MarbleCore
#endif

final class Configuration {
    private let defaults: UserDefaults
    private let key = "settings.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> Settings {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return value.validated()
    }
    func save(_ settings: Settings) {
        if let data = try? JSONEncoder().encode(settings.validated()) { defaults.set(data, forKey: key) }
    }
}
