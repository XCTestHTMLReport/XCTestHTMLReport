//
//  SceneDelegate.swift
//  SampleApp
//
//  UIScene adoption, so the host app still launches on the iOS 27 SDK.
//
//  Until #478 this app was pre-scene UIKit: `UIMainStoryboardFile` plus an
//  `AppDelegate`, with no scene manifest anywhere. On Xcode 26 that is a
//  console warning ("`UIScene` lifecycle will soon be required. Failure to
//  adopt will result in an assert in the future."); on the Xcode 27 SDK the
//  warning becomes the assert, and the app traps at launch:
//
//      Application failed to launch: UIScene life cycle is required for apps
//      built with this SDK.
//
//  The unit tests are hosted in this app, so the trap took `SampleAppUnitTests`
//  with it — 7 XCTest methods and all 5 `@Test` functions, 12 of the fixture's
//  21 rows, gone before a single assertion ran. The UI tests survived only
//  because #423 stopped them launching the host.
//
//  This delegate is deliberately empty. `UISceneStoryboardFile` in the manifest
//  names `Main`, so UIKit instantiates the storyboard's initial view controller
//  and assigns the window itself, exactly as `UIMainStoryboardFile` used to —
//  the `window` property is all it needs from us. Adopting scenes changes which
//  object receives the lifecycle callbacks, not what the app does.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    /// Populated by UIKit from the scene manifest's `UISceneStoryboardFile`.
    /// `UIWindowSceneDelegate` looks this property up by name; without it the
    /// storyboard is loaded into a window nothing retains.
    var window: UIWindow?
}
