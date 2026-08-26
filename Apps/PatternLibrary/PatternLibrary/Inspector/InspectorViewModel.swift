import Observation
import AppleAppLabUI

@MainActor
@Observable
final class InspectorViewModel {
    var config: PatternConfig

    init(config: PatternConfig) {
        self.config = config
    }
}
