import ArgumentParser
import Foundation
import XCTestHTMLReportCore

struct JUnitOptions: ParsableArguments {
    init() {}

    @Flag(name: .shortAndLong, help: ArgumentHelp("Provide JUnit XML output"))
    var junitEnabled = false

    @Flag(
        name: .shortAndLong,
        help: ArgumentHelp(
            "Excludes the run destination information from the generated junit report"
        )
    )
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
        help: ArgumentHelp("Output directory, defaults to the first provided xcresult"),
        completion: .directory
    )
    var output: String?

    @Flag(
        name: .shortAndLong,
        help: ArgumentHelp("Delete unattached files from bundle, reducing bundle size")
    )
    var deleteUnattachedFiles = false
}

struct SummaryOptions: ParsableArguments {
    init() {}

    @ArgumentParser.Argument(
        help: ArgumentHelp(stringLiteral: "Path to one or more .xcresult bundles"),
        completion: .file(extensions: ["xcresult"])
    )
    var results: [String] = []

    @available(*, deprecated, message: "Result bundle paths may be passed as arguments.")
    @Option(
        name: .shortAndLong,
        help: ArgumentHelp(
            "Path to a result bundle (allows multiple)\nDEPRECATED: Result bundle paths may be passed as arguments."
        )
    )
    var resultBundlePath: [String] = []

    var finalResults: [String] {
        results + resultBundlePath
    }

    @Flag(name: .customShort("z"), help: ArgumentHelp("Downsize image screenshots"))
    var downsizeImages = false

    @Option(help: ArgumentHelp("Render attachments inline or as linked assets"))
    var renderingMode: Summary.RenderingMode = .linking

    @Flag(name: .short, help: ArgumentHelp("Render attachments inline or as linked assets"))
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

    @Flag(name: .shortAndLong, help: ArgumentHelp("Provide additional logs"))
    var verbose = false

    @OptionGroup
    var htmlOptions: HtmlOptions

    @OptionGroup
    var junitOptions: JUnitOptions

    @OptionGroup
    var summaryOptions: SummaryOptions

    @OptionGroup
    var jsonOptions: JsonOptions

    func run() async throws {
        Logger.verbose = verbose

        guard let path = htmlOptions.output ?? summaryOptions.finalResults.first?
            .dropLastPathComponent()
        else {
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

        if summaryOptions.finalRenderingMode == .linking, htmlOptions.deleteUnattachedFiles {
            Logger.substep("Deleting unattached files from result bundle")
            summary.deleteUnattachedFiles()
        }

        if junitOptions.junitEnabled {
            let junitXml = summary
                .generatedJunitReport(
                    includeRunDestinationInfo: !junitOptions
                        .excludeRunDestinationInfo
                )
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
            throw ValidationError("Bundles must be provided either by args or the -r option")
        }

        for result in summaryOptions.finalResults {
            guard FileManager.default.fileExists(atPath: result) else {
                throw ValidationError("Bundle \(result) not found")
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
