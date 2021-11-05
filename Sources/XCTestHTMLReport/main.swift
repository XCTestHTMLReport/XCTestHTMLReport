import Foundation
import XCTestHTMLReportCore

var version = "2.1.0"

print("XCTestHTMLReport \(version)")

var command = Command()
var help = BlockArgument("h", "", required: false, helpMessage: "Print usage and available options") {
    print(command.usage)
    exit(EXIT_SUCCESS)
}
var verbose = BlockArgument("v", "", required: false, helpMessage: "Provide additional logs") {
    Logger.verbose = true
}
var junitEnabled = false
var junit = BlockArgument("j", "junit", required: false, helpMessage: "Provide JUnit XML output") {
    junitEnabled = true
}
var result = ValueArgument(
    .path, "r", "resultBundlePath", required: true,
    allowsMultiple: true,
    helpMessage: "Path to a result bundle (allows multiple)")
var renderingMode = RenderingMode.linking
var inlineAssets = BlockArgument(
    "i", "inlineAssets",
    required: false,
    helpMessage: "Inline all assets in the resulting html-file, making it heavier, but more portable") {
    renderingMode = .inline
}
var downsizeImagesEnabled = false
var downsizeImages = BlockArgument(
    "z", "downsize-images",
    required: false,
    helpMessage: "Downsize image screenshots to max width of 200 pixels") {
    downsizeImagesEnabled = true
}
var deleteUnattachedFilesEnabled = false
var deleteUnattachedFiles = BlockArgument(
    "d", "delete-unattached",
    required: false,
    helpMessage: "Delete unattached files from bundle, reducing bundle size. The bundle will not be renderable in Xcode, so make a copy before applying this change") {
    deleteUnattachedFilesEnabled = true
}
var failingTestsOnlyEnabled = false
var failingTestsOnly = BlockArgument(
    "f", "failing-tests-only",
    required: false,
    helpMessage: "Only failng tests will be rendered in the HTML report, This option saves report generation run time when there are a lot of tests in the bundle") {
    failingTestsOnlyEnabled = true
}


command.arguments = [help,
                     verbose,
                     junit,
                     downsizeImages,
                     deleteUnattachedFiles,
                     result,
                     inlineAssets,
                     failingTestsOnly]

if !command.isValid {
    print(command.usage)
    exit(EXIT_FAILURE)
}

let summary = Summary(resultPaths: result.values, renderingArgs: RenderingArguments(renderingMode: renderingMode, failingTestsOnly: failingTestsOnlyEnabled))

Logger.step("Building HTML..")
let html = summary.generatedHtmlReport()

do {
    let path = result.values.first!
        .dropLastPathComponent()
        .addPathComponent("index.html")
    Logger.substep("Writing report to \(path)")

    try html.write(toFile: path, atomically: false, encoding: .utf8)
    Logger.success("\nReport successfully created at \(path)")
}
catch let e {
    Logger.error("An error has occured while creating the report. Error: \(e)")
}

if junitEnabled {
    Logger.step("Building JUnit..")
    let junitXml = summary.generatedJunitReport()
    do {
        let path = "\(result.values.first!)/report.junit"
        Logger.substep("Writing JUnit report to \(path)")

        try junitXml.write(toFile: path, atomically: false, encoding: .utf8)
        Logger.success("\nJUnit report successfully created at \(path)")
    }
    catch let e {
        Logger.error("An error has occured while creating the JUnit report. Error: \(e)")
    }
}

if downsizeImagesEnabled && renderingMode == .linking {
    summary.reduceImageSizes()
}

if deleteUnattachedFilesEnabled && renderingMode == .linking {
    summary.deleteUnattachedFiles()
}

exit(EXIT_SUCCESS)
