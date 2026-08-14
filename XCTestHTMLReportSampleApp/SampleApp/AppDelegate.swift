//
//  AppDelegate.swift
//  SampleApp
//
//  Created by Titouan van Belle on 23.07.17.
//  Copyright © 2017 Tito. All rights reserved.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    /// The environment variable `prepareTestResults.sh` sets — and nothing else
    /// does — when it generates `CrashResults.xcresult`.
    ///
    /// That bundle exists to feed a canary, and a canary for a host-app launch
    /// failure needs a host app that really fails to launch. The
    /// alternative was a scratch copy of the project patched at generation
    /// time, which is a second sample app to keep in step with this one. A trap
    /// nothing sets during a normal run is cheaper and reads as what it is.
    static let trapAtLaunchVariable = "XCHR_TRAP_AT_LAUNCH"

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Deliberate: this is what a host-app launch failure looks like from
        // the inside, and `SystemFailureCanaryTests` needs a bundle carrying
        // one to check that Apple still calls the bucket `System Failures`
        // (#478). Absent the variable — every other invocation in
        // prepareTestResults.sh, and every run from Xcode — this is a no-op.
        if ProcessInfo.processInfo.environment[Self.trapAtLaunchVariable] != nil {
            fatalError("\(Self.trapAtLaunchVariable) is set: trapping at launch on purpose")
        }

        // Override point for customization after application launch.
        return true
    }

    // The five app-level lifecycle stubs that used to sit here
    // (applicationWillResignActive and friends) went with the scene adoption in
    // #478: UIKit delivers those transitions to the scene delegate now, so
    // keeping them would leave five methods nothing ever calls. They were empty
    // Xcode-template comments, so nothing this app does changed.

    /// Hands UIKit the configuration the scene manifest declares.
    ///
    /// The name is matched against `UISceneConfigurationName` in Info.plist at
    /// run time, and nothing checks it at compile time. Rename it on one side
    /// only and this still builds: UIKit vends an unmatched configuration, with
    /// no delegate class and no storyboard behind it, and the app comes up as a
    /// blank window. Keep the two spellings in step by hand — the compiler will
    /// not. See `SceneDelegate` for why adoption is required at all.
    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
