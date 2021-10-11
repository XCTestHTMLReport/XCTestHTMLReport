import ArgumentParser
import Foundation
import XCTestHTMLReportCore


struct XcTestHtmlReport: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "xchtmlreport",
        version: "2.1.1",
        shouldDisplay: true)

    @Argument(
        help: ArgumentHelp("results_arg_help".localized),
        completion: .file(extensions: ["xcresult"]))
    var results: [String] = []

    @available(*, deprecated, message: "Result bundle paths may be passed as arguments.")
    @Option(
        name: .shortAndLong,
        help: ArgumentHelp("resultBundlePath_opt_help".localized))
    var resultBundlePath: [String] = []

    @Option(help: ArgumentHelp("renderingMode_opt_help".localized))
    var renderingMode: Summary.RenderingMode = .linking

    @Option(
        name: .shortAndLong, parsing: .next,
        help: ArgumentHelp("output_opt_help".localized), completion: .directory)
    var output: String?

    @Flag(name: .shortAndLong, help: ArgumentHelp("verbose_flag_help".localized))
    var verbose = false

    @Flag(name: .shortAndLong, help: ArgumentHelp("junitEnabled_flag_help".localized))
    var junitEnabled = false

    @Flag(name: .long, help: ArgumentHelp("downsizeImages_flag_help".localized))
    var downsizeImages = false

    @Flag(name: .shortAndLong, help: ArgumentHelp("deleteUnattachedFiles_flag_help".localized))
    var deleteUnattachedFiles = false

    func validate() throws {
        guard !results.isEmpty || !resultBundlePath.isEmpty else {
            throw ValidationError("result_bundle_not_provided".localized)
        }

        for result in (results + resultBundlePath) {
            guard FileManager.default.fileExists(atPath: result) else {
                throw ValidationError(String(format: "result_bundle_missing".localized, result))
            }
        }
    }

    func run() throws {
        Logger.verbose = verbose

        let completeResults = results + resultBundlePath

        guard
            let path = output
                ?? completeResults.first?
                .dropLastPathComponent()
                .addPathComponent("index.html")
        else {
            throw ExitCode(EXIT_FAILURE)
        }
        Logger.substep("Writing report to \(path)")

        let summary = Summary(resultPaths: completeResults, renderingMode: renderingMode)

        Logger.step("Building HTML..")
        let html = summary.generatedHtmlReport()

        do {
            try html.write(toFile: path, atomically: false, encoding: .utf8)
        } catch {
            Logger.error("An error has occured while creating the report.")
            throw error
        }

        Logger.success("\nReport successfully created at \(path)")

        if renderingMode == .linking {
            if downsizeImages {
                summary.reduceImageSizes()
            }

            if deleteUnattachedFiles {
                summary.deleteUnattachedFiles()
            }
        }

        if junitEnabled {
            let junitXml = summary.generatedJunitReport()
            let junitPath = path.dropLastPathComponent().addPathComponent("report.junit")
            Logger.substep("Writing JUnit report to \(junitPath)")

            do {
                try junitXml.write(toFile: junitPath, atomically: false, encoding: .utf8)
                Logger.success("\nJUnit report successfully created at \(junitPath)")
            } catch {
                Logger.error("An error has occured while creating the JUnit report.")
                throw error
            }
        }
    }
}

XcTestHtmlReport.main()

extension Summary.RenderingMode: ExpressibleByArgument {}

extension String {
    fileprivate var localized: String {
        NSLocalizedString(self, bundle: .module, comment: "")
    }
}
