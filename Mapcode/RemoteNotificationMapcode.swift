//
//  RemoteNotificationMapcode.swift
//  Mapcode
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

import UIKit

let RemoteNotificationMapcodeAppSectionKey: String = "mapcode"

class RemoteNotificationMapcode: NSObject {
    var text: String = ""

    class func create(userInfo: [NSObject:AnyObject]) -> RemoteNotificationMapcode? {
        let info = userInfo as NSDictionary
        self.text = info.objectForKey(RemoteNotificationMapcodeAppSectionKey) as! String
        return self
    }


    private override init() {
        self.text = ""
        super.init()
    }


    private init(providedText: String) {
        self.text = providedText
        super.init()
    }


    final func trigger() {
        dispatch_async(dispatch_get_main_queue()) {
            print("Triggering Deep Link - %@", self) // TODO
                var vc = UIViewController()
                vc = ViewController()
                // TODO
//                let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
//                appDelegate.window?.addSubview(vc.view)
//                completion(nil)

        }
    }

}
