import Foundation
import DriveIconGuardIPC
import DriveIconGuardScopeInventory
import DriveIconGuardShared

public struct AttributedArtefactClassifier {
    private let rules: [ArtefactRule]

    public init(rules: [ArtefactRule] = ArtefactScanner.defaultRules) {
        self.rules = rules
    }

    public func matchedArtefact(for event: ProcessAttributedFileEvent) -> ArtefactType? {
        let filename = URL(fileURLWithPath: event.targetPath).lastPathComponent

        return rules.first { rule in
            switch rule.matchType {
            case .exactPath:
                return event.targetPath == rule.matchValue
            case .filename:
                return filename == rule.matchValue
            case .metadataKey:
                return false
            case .regex:
                return filename.range(of: rule.matchValue, options: .regularExpression) != nil
            }
        }?.artefactType
    }
}
