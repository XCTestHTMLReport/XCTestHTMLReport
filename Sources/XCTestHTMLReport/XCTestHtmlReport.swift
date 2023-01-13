import ArgumentParser
import Foundation
import XCTestHTMLReportCore

struct JUnitOptions: ParsableArguments {
    init() {}

    @Flag(name: .shortAndLong, help: ArgumentHelp("junitEnabled_flag_help".localized))
    var junitEnabled = false

    @Flag(name: .shortAndLong, help: ArgumentHelp("excludeRunDestinationInfo_flag_help".localized))
    var excludeRunDestinationInfo = false
}

struct JsonOptions: ParsableArguments {

    @Flag(name: .customLong("json"), help: ArgumentHelp("Output result.json"))
    var jsonEnabled = false

}

struct HtmlOptions: ParsableArguments {
    init() {}

    @Option(
        name: .shortAndLong,
        parsing: .next,
        help: ArgumentHelp("output_opt_help".localized),
        completion: .directory
    )
    var output: String?

    @Flag(name: .shortAndLong, help: ArgumentHelp("deleteUnattachedFiles_flag_help".localized))
    var deleteUnattachedFiles = false
}

struct SummaryOptions: ParsableArguments {
    init() {}
    
    @ArgumentParser.Argument(
        help: ArgumentHelp(stringLiteral: "results_arg_help".localized),
        completion: .file(extensions: ["xcresult"])
    )
    var results: [String] = []

    @available(*, deprecated, message: "Result bundle paths may be passed as arguments.")
    @Option(
        name: .shortAndLong,
        help: ArgumentHelp("resultBundlePath_opt_help".localized)
    )
    var resultBundlePath: [String] = []
    
    var finalResults: [String] {
        results + resultBundlePath
    }
    
    @Flag(name: .customShort("z"), help: ArgumentHelp("downsizeImages_flag_help".localized))
    var downsizeImages = false
    
    @Option(help: ArgumentHelp("renderingMode_opt_help".localized))
    var renderingMode: Summary.RenderingMode = .linking

    @Flag(name: .short, help: ArgumentHelp("renderingMode_opt_help".localized))
    var inline = false
    
    var finalRenderingMode: Summary.RenderingMode {
        if renderingMode == .inline || inline {
            return .inline
        }
        return .linking
    }
}

@main
struct XCTestHtmlReport: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "xchtmlreport",
        version: version,
        shouldDisplay: true
    )

    @Flag(name: .shortAndLong, help: ArgumentHelp("verbose_flag_help".localized))
    var verbose = false
    
    @OptionGroup
    var htmlOptions: HtmlOptions

    @OptionGroup
    var junitOptions: JUnitOptions
    
    @OptionGroup
    var summaryOptions: SummaryOptions
    
    @OptionGroup
    var jsonOptions: JsonOptions
}

extension XCTestHtmlReport {
    func run() async throws {
        Logger.verbose = verbose

        guard let path = htmlOptions.output ?? summaryOptions.finalResults.first?.dropLastPathComponent() else {
            throw ExitCode(EXIT_FAILURE)
        }

        let indexPath = path.addPathComponent("index.html")

        Logger.substep("Writing report to \(path)")

        let summary = Summary(
            resultPaths: summaryOptions.finalResults,
            renderingMode: summaryOptions.finalRenderingMode,
            downsizeImagesEnabled: summaryOptions.downsizeImages
        )

        Logger.step("Building HTML..")
        let html = summary.generatedHtmlReport()

        do {
            try html.write(toFile: indexPath, atomically: false, encoding: .utf8)
        } catch {
            Logger.error("An error has occured while creating the report")
            throw error
        }

        Logger.success("\nReport successfully created at \(indexPath)")

        if summaryOptions.finalRenderingMode == .linking && htmlOptions.deleteUnattachedFiles {
            Logger.substep("Deleting unattached files from result bundle")
            summary.deleteUnattachedFiles()
        }

        if junitOptions.junitEnabled {
            let junitXml = summary
                .generatedJunitReport(includeRunDestinationInfo: !junitOptions.excludeRunDestinationInfo)
            let junitPath = path.addPathComponent("report.junit")
            Logger.substep("Writing JUnit report to \(junitPath)")

            do {
                try junitXml.write(toFile: junitPath, atomically: false, encoding: .utf8)
                Logger.success("\nJUnit report successfully created at \(junitPath)")
            } catch {
                Logger.error("An error has occured while creating the JUnit report.")
                throw error
            }
        }
        
        if jsonOptions.jsonEnabled {

            let json = summary.generatedJsonReport()
            let jsonPath = path.addPathComponent("report.json")
            Logger.substep("Writing JSON report to \(jsonPath)")
            
            do {
                try json.write(toFile: jsonPath, atomically: false, encoding: .utf8)
                Logger.success("\nJSON report successfully created at \(jsonPath)")
            } catch {
                Logger.error("An error has occurred while creating the JSON report.")
                throw error
            }

        }
    }

    func validate() throws {
        guard !summaryOptions.finalResults.isEmpty else {
            throw ValidationError("result_bundle_not_provided".localized)
        }

        for result in summaryOptions.finalResults {
            guard FileManager.default.fileExists(atPath: result) else {
                throw ValidationError(String(format: "result_bundle_missing".localized, result))
            }
        }
    }
}

extension Summary.RenderingMode: ExpressibleByArgument {
    public init?(argument: String) {
        switch argument {
        case "inline":
            self = .inline
        default:
            self = .linking
        }
    }
}

private extension String {
    var localized: String {
        NSLocalizedString(self, bundle: .module, comment: "")
    }
}
