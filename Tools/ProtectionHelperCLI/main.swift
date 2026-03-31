import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import Foundation

private struct HelperHostOptions {
    var eventsPath: String?
    var snapshotPath: String?
    var useFreshScan = false
    var emitJSON = false
    var showHelp = false
}

private enum HelperHostError: LocalizedError {
    case missingEventsPath
    case invalidArguments(String)

    var errorDescription: String? {
        switch self {
        case .missingEventsPath:
            return "Missing required `--events <path>` argument."
        case .invalidArguments(let message):
            return message
        }
    }
}

@main
struct DriveIconGuardHelperCLI {
    static func main() {
        do {
            let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))

            if options.showHelp {
                printUsage()
                return
            }

            guard let eventsPath = options.eventsPath else {
                throw HelperHostError.missingEventsPath
            }

            let report = try loadReport(using: options)
            let subscriber = try ReplayProcessAttributedEventSubscriber(fileURL: URL(fileURLWithPath: eventsPath))
            let service = HelperProtectionService(subscriber: subscriber)

            service.updateScopes(report.scopes)
            service.start { evaluation in
                print(render(evaluation, emitJSON: options.emitJSON))
            }

            guard subscriber.waitUntilFinished() else {
                throw HelperHostError.invalidArguments("Timed out while replaying attributed events from \(eventsPath).")
            }

            service.stop()
        } catch {
            fputs("drive-icon-guard-helper: \(error.localizedDescription)\n", stderr)
            printUsage(to: stderr)
            Foundation.exit(1)
        }
    }

    private static func parseOptions(arguments: [String]) throws -> HelperHostOptions {
        var options = HelperHostOptions()
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--events":
                index += 1
                guard index < arguments.count else {
                    throw HelperHostError.invalidArguments("Expected a file path after `--events`.")
                }
                options.eventsPath = arguments[index]
            case "--snapshot":
                index += 1
                guard index < arguments.count else {
                    throw HelperHostError.invalidArguments("Expected a file path after `--snapshot`.")
                }
                options.snapshotPath = arguments[index]
            case "--fresh-scan":
                options.useFreshScan = true
            case "--json":
                options.emitJSON = true
            case "--help", "-h":
                options.showHelp = true
            default:
                throw HelperHostError.invalidArguments("Unknown argument `\(arguments[index])`.")
            }

            index += 1
        }

        return options
    }

    private static func loadReport(using options: HelperHostOptions) throws -> ScopeInventoryReport {
        if options.useFreshScan {
            return ScopeInventoryService().generateReport()
        }

        if let snapshotPath = options.snapshotPath {
            return try ScopeInventoryPersistence().loadReport(at: URL(fileURLWithPath: snapshotPath))
        }

        return ScopeInventoryService().generateReport()
    }

    private static func render(_ evaluation: HelperProtectionEvaluation, emitJSON: Bool) -> String {
        if emitJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(evaluation),
                  let string = String(data: data, encoding: .utf8) else {
                return "{\"decision\":\"\(evaluation.decision.rawValue)\",\"reason\":\"\(evaluation.reason)\"}"
            }
            return string
        }

        let scopeID = evaluation.matchedScopeID?.uuidString ?? "none"
        let artefact = evaluation.matchedArtefactType?.rawValue ?? "none"
        return "[\(evaluation.decision.rawValue)] scope=\(scopeID) artefact=\(artefact) path=\(evaluation.event.targetPath) reason=\(evaluation.reason)"
    }

    private static func printUsage(to stream: UnsafeMutablePointer<FILE> = stdout) {
        fputs(
            """
            Usage: drive-icon-guard-helper --events <path> [--snapshot <report.json> | --fresh-scan] [--json]

              --events <path>    JSON array or JSONL file containing ProcessAttributedFileEvent records.
              --snapshot <path>  Persisted inventory snapshot to use for scope evaluation.
              --fresh-scan       Generate a new inventory report instead of loading a snapshot.
              --json             Emit JSON evaluations instead of human-readable lines.
              --help             Show this message.

            Notes:
              This helper host currently supports replay/test event input only.
              Live Google-Drive-only blocking still requires a macOS Endpoint Security event source.

            """,
            stream
        )
    }
}
