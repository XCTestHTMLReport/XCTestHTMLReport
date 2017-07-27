//
//  main.swift
//  XCUITestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

var result = Argument(.path, "r", "resultBundePath", required: true, helpMessage: "Path to the result bundle")
var command = Command(arguments: [result])

if !command.isValid {
    print(command.usage)
    exit(EXIT_FAILURE)
}

let summary = Summary(root: result.value!)
let activityLogs = summary.activityLogs

do {
    try activityLogs.write(toFile: "\(result.value!)/logs.txt", atomically: false, encoding: .utf8)
}
catch {
    print("An error has occured while create the activity log file")
}

let html = summary.html

do {
    let path = "\(result.value!)/index.html"
    try html.write(toFile: path, atomically: false, encoding: .utf8)
    print("Report successfully created at \(path)")
}
catch {
    print("An error has occured while creating the report")
}

exit(EXIT_SUCCESS)
