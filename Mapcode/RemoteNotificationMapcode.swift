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

        let mapcode = info.objectForKey(RemoteNotificationMapcodeAppSectionKey) as! String
        var ret: RemoteNotificationMapcode? = nil
        if !mapcode.isEmpty {
            ret = RemoteNotificationMapcodeSearch(text: mapcode)
        }
        return ret
    }


    private override init() {
        self.text = ""
        super.init()
    }


    private init(text: String) {
        self.text = text
        super.init()
    }


    final func trigger() {
        dispatch_async(dispatch_get_main_queue()) {
            // TODO print("trigger: text=\(self.text)")
            self.triggerImp() {
                (passedData) in

                // Do nothing.
            }
        }
    }


    private func triggerImp(completion: ((AnyObject?) -> (Void))) {
        completion(nil)
    }
}


class RemoteNotificationMapcodeSearch: RemoteNotificationMapcode {
    var mapcode: String!


    override init(text: String) {
        self.mapcode = text
        super.init(text: text)
    }


    private override func triggerImp(completion: ((AnyObject?) -> (Void))) {
        super.triggerImp() {
            (passedData) in

            // TODO print("trigger2: text=\(self.text, self.mapcode)")
//
//            var vc = UIViewController()
//            vc = ViewController()
//
//            let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
//            appDelegate.window?.addSubview(vc.view)

            completion(nil)
        }
    }
}