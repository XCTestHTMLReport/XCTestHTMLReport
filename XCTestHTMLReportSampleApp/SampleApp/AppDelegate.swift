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
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Override point for customization after application launch.
        true
    }

    // The five app-level lifecycle stubs that used to sit here
    // (applicationWillResignActive and friends) went with the scene adoption in
    // #478: UIKit delivers those transitions to the scene delegate now, so
    // keeping them would leave five methods nothing ever calls. They were empty
    // Xcode-template comments, so nothing this app does changed.

    /// The scene manifest already declares this configuration; naming it here
    /// is what ties `UISceneConfigurationName` in Info.plist to the code, so a
    /// rename on one side stops compiling rather than silently falling back to
    /// a default scene. See `SceneDelegate` for why adoption is required at all.
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
