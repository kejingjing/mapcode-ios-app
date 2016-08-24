//
// AppDelegate.swift
// Mapcode
//
// Copyright (C) 2016 Stichting Mapcode Foundation (http://www.mapcode.com)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var loadedEnoughToStartMapcode: Bool = false
    var mapcodeNotification: RemoteNotificationMapcode?


    func application(application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [NSObject:AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }


    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
        print("application: url=\(url)")
        if url.host == nil {
            return true;
        }

        let urlString = url.absoluteString
        let queryArray = urlString.componentsSeparatedByString("/")
        print("application: queryArray=\(queryArray)")
        let query = queryArray[2]
        let userInfo = [RemoteNotificationMapcodeAppSectionKey: query]
        self.applicationHandleRemoteNotification(application, didReceiveRemoteNotification: userInfo)
        return true
    }


    func applicationHandleRemoteNotification(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject: AnyObject]) {
        print("applicationHandleRemoteNotification: application=\(application), userInfo=\(userInfo)")
        if (application.applicationState == UIApplicationState.Background) || (application.applicationState == UIApplicationState.Inactive) {
            let canDoNow = loadedEnoughToStartMapcode
            self.mapcodeNotification = RemoteNotificationMapcode.create(userInfo)
            if canDoNow {
                self.triggerMapcodeIfPresent()
            }
        }
    }


    func triggerMapcodeIfPresent() -> Bool {
        print("triggerMapcodeIfPresent: \(self.mapcodeNotification)")
        self.loadedEnoughToStartMapcode = true
        let ret = (self.mapcodeNotification?.trigger() != nil)
        self.mapcodeNotification = nil
        return ret
    }


    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }


    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }


    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }


    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }


    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

