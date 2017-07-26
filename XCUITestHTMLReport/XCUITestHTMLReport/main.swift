//
//  main.swift
//  XCUITestHTMLReport
//
//  Created by Titouan van Belle on 21.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import Foundation

let arguments = Arguments(arguments: CommandLine.arguments)

guard arguments.results != nil else {
    print("Argument -r is missing")
    exit(EXIT_FAILURE)
}

let summary = Summary(root: arguments.results!)
let activityLogs = summary.activityLogs

do {
    try activityLogs.write(toFile: "\(arguments.results!)/logs.txt", atomically: false, encoding: .utf8)
}
catch {
    print("An error has occured while create the activity log file")
}

let html = summary.html

do {
    let path = "\(arguments.results!)/index.html"
    try html.write(toFile: path, atomically: false, encoding: .utf8)
    print("Report successfully created at \(path)")
}
catch {
    print("An error has occured while creating the report")
}

exit(EXIT_SUCCESS)
