import DriveIconGuardHelper
import DriveIconGuardIPC
import DriveIconGuardScopeInventory
import DriveIconGuardShared
import DriveIconGuardXPCClient
import Foundation

private struct HelperHostOptions {
    var eventsPath: String?
    var snapshotPath: String?
    var useFreshScan = false
    var emitJSON = false
    var showStatus = false
    var installService = false
    var bootstrapService = false
    var bootoutService = false
    var showServiceStatus = false
    var uninstallService = false
    var showInstallPlan = false
    var runXPCService = false
    var machServiceName: String?
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

            if options.showStatus {
                let eventSourceStatus = EndpointSecurityProcessAttributedEventSubscriber().status
                let installationStatus = currentInstallationStatus()
                print(render(eventSourceStatus: eventSourceStatus, installationStatus: installationStatus, emitJSON: options.emitJSON))
                return
            }

            if options.showInstallPlan {
                let plan = try ProtectionServiceInstaller().plan()
                print(render(plan: plan, emitJSON: options.emitJSON))
                return
            }

            if options.installService {
                let receipt = try ProtectionServiceInstaller().install()
                print(render(receipt: receipt, emitJSON: options.emitJSON))
                return
            }

            if options.bootstrapService {
                let result = try ProtectionServiceDeploymentCoordinator().installAndBootstrap()
                print(render(deploymentResult: result, emitJSON: options.emitJSON))
                return
            }

            if options.bootoutService {
                let status = try ProtectionServiceDeploymentCoordinator().bootoutAndUninstall()
                print(render(launchdStatus: status, emitJSON: options.emitJSON))
                return
            }

            if options.showServiceStatus {
                let status = try ProtectionServiceDeploymentCoordinator().status()
                print(render(launchdStatus: status, emitJSON: options.emitJSON))
                return
            }

            if options.uninstallService {
                try ProtectionServiceInstaller().uninstall()
                print(options.emitJSON ? "{\"status\":\"uninstalled\"}" : "Helper service registration files removed.")
                return
            }

            if options.runXPCService {
                let machServiceName = options.machServiceName ?? ProtectionServiceRegistrationConfiguration.beta.machServiceName
                _ = ProtectionXPCListenerHost(machServiceName: machServiceName)
                if !options.emitJSON {
                    print("drive-icon-guard-helper is serving NSXPC requests on \(machServiceName)")
                }
                RunLoop.main.run()
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
            case "--status":
                options.showStatus = true
            case "--install-service":
                options.installService = true
            case "--bootstrap-service":
                options.bootstrapService = true
            case "--bootout-service":
                options.bootoutService = true
            case "--service-status":
                options.showServiceStatus = true
            case "--uninstall-service":
                options.uninstallService = true
            case "--install-plan":
                options.showInstallPlan = true
            case "--xpc-service":
                options.runXPCService = true
            case "--mach-service-name":
                index += 1
                guard index < arguments.count else {
                    throw HelperHostError.invalidArguments("Expected a mach service name after `--mach-service-name`.")
                }
                options.machServiceName = arguments[index]
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

    private static func render(
        eventSourceStatus: ProtectionEventSourceStatus,
        installationStatus: ProtectionInstallationStatus,
        emitJSON: Bool
    ) -> String {
        if emitJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let payload = HelperStatusPayload(
                eventSourceStatus: eventSourceStatus,
                installationStatus: installationStatus
            )
            guard let data = try? encoder.encode(payload),
                  let string = String(data: data, encoding: .utf8) else {
                return "{\"eventSourceState\":\"\(eventSourceStatus.state.rawValue)\",\"installationState\":\"\(installationStatus.state.rawValue)\"}"
            }
            return string
        }

        return "[event:\(eventSourceStatus.state.rawValue)] \(eventSourceStatus.detail)\n[install:\(installationStatus.state.rawValue)] \(installationStatus.detail)"
    }

    private static func currentInstallationStatus() -> ProtectionInstallationStatus {
        let resolver = ProtectionInstallationStatusResolver()
        return resolver.resolve(helperPath: ProtectionHelperHostLocator().locate()?.path)
    }

    private static func installerResourceURL() -> URL? {
        let bundleRoot = Bundle.main.bundleURL
        let bundledURL = bundleRoot.appendingPathComponent("Contents/Resources/Installer/ServiceRegistration", isDirectory: true)
        if FileManager.default.fileExists(atPath: bundledURL.path) {
            return bundledURL
        }

        let repoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("Installer/ServiceRegistration", isDirectory: true)
        if FileManager.default.fileExists(atPath: repoURL.path) {
            return repoURL
        }

        return nil
    }

    private static func render(plan: ProtectionServiceRegistrationPlan, emitJSON: Bool) -> String {
        if emitJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(plan),
                  let string = String(data: data, encoding: .utf8) else {
                return "{\"machServiceName\":\"\(plan.machServiceName)\"}"
            }
            return string
        }

        return """
        LaunchAgent label: \(plan.launchdLabel)
        Mach service: \(plan.machServiceName)
        Helper executable: \(plan.helperExecutablePath)
        LaunchAgent plist: \(plan.launchAgentPlistPath)
        Receipt: \(plan.receiptPath)
        """
    }

    private static func render(receipt: ProtectionInstallationReceipt, emitJSON: Bool) -> String {
        if emitJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(receipt),
                  let string = String(data: data, encoding: .utf8) else {
                return "{\"state\":\"\(receipt.state.rawValue)\"}"
            }
            return string
        }

        return """
        [install:\(receipt.state.rawValue)] \(receipt.detail)
        helper=\(receipt.helperExecutablePath ?? "none")
        machService=\(receipt.machServiceName ?? "none")
        launchAgent=\(receipt.launchAgentPlistPath ?? "none")
        """
    }

    private static func render(deploymentResult: ProtectionServiceDeploymentResult, emitJSON: Bool) -> String {
        if emitJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(deploymentResult),
                  let string = String(data: data, encoding: .utf8) else {
                return "{\"state\":\"\(deploymentResult.receipt.state.rawValue)\"}"
            }
            return string
        }

        return """
        [install:\(deploymentResult.receipt.state.rawValue)] \(deploymentResult.receipt.detail)
        [launchd:\(deploymentResult.launchdStatus.isLoaded ? "loaded" : "not loaded")] \(deploymentResult.launchdStatus.detail)
        service=\(deploymentResult.launchdStatus.serviceTarget)
        """
    }

    private static func render(launchdStatus: ProtectionServiceLaunchdStatus, emitJSON: Bool) -> String {
        if emitJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(launchdStatus),
                  let string = String(data: data, encoding: .utf8) else {
                return "{\"serviceTarget\":\"\(launchdStatus.serviceTarget)\",\"isLoaded\":\(launchdStatus.isLoaded ? "true" : "false")}"
            }
            return string
        }

        return """
        [launchd:\(launchdStatus.isLoaded ? "loaded" : "not loaded")] \(launchdStatus.detail)
        domain=\(launchdStatus.domainTarget)
        service=\(launchdStatus.serviceTarget)
        """
    }

    private static func printUsage(to stream: UnsafeMutablePointer<FILE> = stdout) {
        fputs(
            """
            Usage: drive-icon-guard-helper --events <path> [--snapshot <report.json> | --fresh-scan] [--json]
                   drive-icon-guard-helper --status [--json]
                   drive-icon-guard-helper --install-plan [--json]
                   drive-icon-guard-helper --install-service [--json]
                   drive-icon-guard-helper --bootstrap-service [--json]
                   drive-icon-guard-helper --bootout-service [--json]
                   drive-icon-guard-helper --service-status [--json]
                   drive-icon-guard-helper --uninstall-service [--json]
                   drive-icon-guard-helper --xpc-service [--mach-service-name <name>]

              --events <path>    JSON array or JSONL file containing ProcessAttributedFileEvent records.
              --snapshot <path>  Persisted inventory snapshot to use for scope evaluation.
              --fresh-scan       Generate a new inventory report instead of loading a snapshot.
              --status           Show the current Endpoint Security subscriber readiness state.
              --install-plan     Show the launch-agent + receipt paths used for helper registration.
              --install-service  Write launch-agent registration and installation receipt files.
              --bootstrap-service Write registration files, then run launchctl bootstrap + kickstart.
              --bootout-service  Run launchctl bootout when loaded, then remove registration files.
              --service-status   Show launchctl print status for the named helper service.
              --uninstall-service Remove launch-agent registration and installation receipt files.
              --xpc-service      Run the helper as a named NSXPC service host.
              --mach-service-name Override the mach service name used with `--xpc-service`.
              --json             Emit JSON evaluations instead of human-readable lines.
              --help             Show this message.

            Notes:
              This helper host currently supports replay/test event input only.
              Live Google-Drive-only blocking still requires a macOS Endpoint Security event source.
              The service-install path writes launch-agent and receipt files but does not replace signing, approval, or real ES entitlement work.

            """,
            stream
        )
    }
}

private struct HelperStatusPayload: Codable {
    var eventSourceStatus: ProtectionEventSourceStatus
    var installationStatus: ProtectionInstallationStatus
}
