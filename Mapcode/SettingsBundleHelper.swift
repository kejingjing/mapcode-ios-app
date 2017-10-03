//
//  SettingsBundleHelper.swift
//  Mapcode
//
//  Created by Rijn Buve on 03-10-17.
//  Copyright © 2017 Mapcode Foundation. All rights reserved.
//

import Foundation

class SettingsBundleHelper {

    struct SettingsBundleKeys {
        static let keySendUserFeedback = "keySendUserFeedback"
        static let keyVersionBuild = "keyVersionBuild"
        static let keyPrevVersionBuild = "keyPrevVersionBuild"
    }

    class func checkAndExecuteSettings() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: SettingsBundleKeys.keySendUserFeedback) {
            // Use setting. Currently checked periodically.
        }
    }

    class func setVersionAndBuildNumber() {
        let defaults = UserDefaults.standard
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let build = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
        let versionBuild = "\(version) (\(build))"
        defaults.set(versionBuild, forKey: SettingsBundleKeys.keyVersionBuild)
    }
}
