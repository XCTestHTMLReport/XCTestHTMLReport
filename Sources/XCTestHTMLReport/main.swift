import Foundation

var version = "2.1.1"

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
var downsizeImagesEnabled = false
var downsizeImages = BlockArgument("z", "downsize-images", required: false, helpMessage: "Downsize image screenshots") {
    downsizeImagesEnabled = true
}
var deleteUnattachedFilesEnabled = false
var deleteUnattachedFiles = BlockArgument("d", "delete-unattached", required: false, helpMessage: "Delete unattached files from bundle, reducing bundle size") {
    deleteUnattachedFilesEnabled = true
}


command.arguments = [help,
                     verbose,
                     junit,
                     downsizeImages,
                     deleteUnattachedFiles,
                     result,
                     inlineAssets]

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

if downsizeImagesEnabled && renderingMode == .linking {
    Logger.substep("Resizing images..")
    var resizedCount = 0
    for run in summary.runs {
        for screenshotAttachment in run.screenshotAttachments {
            let resized = resizeImage(atPath: run.file.url.path + "/../" + (screenshotAttachment.source ?? ""))
            if resized {
                resizedCount += 1
            }
        }
    }
    Logger.substep("Finished resizing \(resizedCount) images")
}

if deleteUnattachedFilesEnabled && renderingMode == .linking {
    for run in summary.runs {
        let files = removeUnattachedFiles(run: run)
        Logger.substep("Deleted \(files) unattached files")
    }
}

exit(EXIT_SUCCESS)
