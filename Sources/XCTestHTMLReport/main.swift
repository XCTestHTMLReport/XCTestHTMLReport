import Darwin

var version = "2.0.0"

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
var result = ValueArgument(.path, "r", "resultBundlePath", required: true, allowsMultiple: true, helpMessage: "Path to a result bundle (allows multiple)")
var renderingMode = Summary.RenderingMode.linking
var inlineAssets = BlockArgument("i", "inlineAssets", required: false, helpMessage: "Inline all assets in the resulting html-file, making it heavier, but more portable") {
    renderingMode = .inline
}

command.arguments = [help, verbose, junit, result, inlineAssets]

if !command.isValid {
    print(command.usage)
    exit(EXIT_FAILURE)
}

let summary = Summary(resultPaths: result.values, renderingMode: renderingMode)

Logger.step("Building HTML..")
let html = summary.html

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
    let junitXml = summary.junit.xmlString
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

exit(EXIT_SUCCESS)
