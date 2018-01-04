//
// ViewController.swift
// Mapcode
//
// Copyright (C) 2016-2018, Stichting Mapcode Foundation (http://www.mapcode.com)
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

import CoreLocation
import MapKit
import UIKit
import Contacts
import mapcodelib


// Consider refactoring the code to use the non-optional operators.
fileprivate func <<T:Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}


// Consider refactoring the code to use the non-optional operators.
fileprivate func >=<T:Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l >= r
    default:
        return !(lhs < rhs)
    }
}


class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate,
        UITextFieldDelegate, UIGestureRecognizerDelegate {
    /**
     * List of UI controls that we need to access from code.
     */

    @IBOutlet weak var theMap: MKMapView!
    @IBOutlet weak var theFindMyLocation: UIButton!
    @IBOutlet weak var theAddress: UITextField!
    @IBOutlet weak var theAddressLabel: UILabel!
    @IBOutlet weak var theAddressFirstLine: UILabel!
    @IBOutlet weak var theContext: UITextView!
    @IBOutlet weak var theContextLabel: UILabel!
    @IBOutlet weak var theNextContext: UIButton!
    @IBOutlet weak var theMapcode: UITextView!
    @IBOutlet weak var theMapcodeLabel: UILabel!
    @IBOutlet weak var theNextMapcode: UIButton!
    @IBOutlet weak var theLat: UITextField!
    @IBOutlet weak var theLon: UITextField!
    @IBOutlet weak var theLatLabel: UILabel!
    @IBOutlet weak var theLonLabel: UILabel!
    @IBOutlet weak var theView: UIView!
    @IBOutlet weak var theUseMapcodeLibrary: UISwitch!
    @IBOutlet weak var keyboardHeightLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var theOnlineAPIIndicator: UILabel!

    //@formatter:off

    /**
     * Constants.
     */

    // Current debug messages mask.
#if DEBUG
    let debugMask: UInt8 = 0xFE
#else
    let debugMask: UInt8 = 0x00
#endif

    let TRACE: UInt8 = 1
    let DEBUG: UInt8 = 2
    let INFO: UInt8 = 4
    let WARN: UInt8 = 8
    let ERROR: UInt8 = 16

    // Help texts.
    let textWhatsNew = "\n" +
        "* Copying latitude and longitude is now a single click.\n" +
        "* Minor improvements.\n";

    let textAbout = "Copyright (C) 2016-2018\n" +
        "Rijn Buve, Mapcode Foundation\n\n" +

        "Welcome the official Mapcode App from the Mapcode Foundation!\n\n" +

        "Enter an address or coordinate to get a mapcode, or move the map around.\n\n" +

        "Tap twice on the map to zoom in really deep.\n\n" +

        "Enter a mapcode in the address field to show it on the map. Tip: if you omit " +
        "the territory for local mapcodes, the current territory is used.\n\n" +

        "Tap the territory to scroll through the territories/countries.\n\n" +

        "Tap the mapcode itself to copy it to the clipboard.\n\n" +

        "Tap on the Share button to share the mapcode with any other app.\n\n" +

        "Tap on the Maps icon to plan a route to it using the Maps app.\n\n" +

        "Note that a single location can have mapcodes with different territory codes. " +
        "The 'correct' territory is always included, but other territories may be presented as well.\n\n" +

        "For questions, or more info on mapcodes in general, please visit us at:\n" +
        "http://mapcode.com\n\n" +

        "Finally, a big thanks to our many beta-testers who have provided invaluable " +
        "feedback during the development of this product!\n\n" +

        "________\n" +

        "Privacy notice: " +
        "This app may use the Mapcode REST API at https://api.mapcode.com. " +
        "This free online service is provided for demonstration purposes " +
        "only and the Mapcode Foundation accepts no claims " +
        "on its availability or reliability, although we try hard to " +
        "provide a stable and decent service. Note that anonymized " +
        "usage and log data, including mapcodes and coordinates, may " +
        "be collected to improve the service and better anticipate " +
        "on its scalability needs. The collected data contains no IP " +
        "addresses, is processed securely in the EEA and is never " +
    "sold or used for commercial purposes."

    // Other constants.
#if DEBUG
    let allowLog: String = "false"                  // API: No logging requests.
#else
    let allowLog: String = "true"                   // API: Allow logging requests.
#endif

    let host: String = "https://api.mapcode.com"    // Host name of Mapcode REST API.
    let client: String = "ios"                      // API: Client ID.
    let tagTextFieldAddress = 1                     // Tags of text fields.
    let tagTextFieldLatitude = 2
    let tagTextFieldLongitude = 3

    let mapcodeTerritoryFont = "HelveticaNeue"      // Font definitions.
    let mapcodeCodeFont = "HelveticaNeue-Bold"
    let mapcodeInternationalFont = "HelveticaNeue-Bold"
    let contextFont = "HelveticaNeue-Medium"
    let mapcodeTerritoryFontSize: CGFloat = 12.0
    let mapcodeCodeFontSize: CGFloat = 16.0
    let mapcodeCodeFontSizeSmall: CGFloat = 12.0
    let mapcodeInternationalFontSize: CGFloat = 16.0
    let contextFontSize: CGFloat = 16.0
    let mapcodeFontKern = 0.65

    let colorMapcode = UIColor.black         // Colors of mapcode and its territory prefix.
    let colorTerritoryPrefix = UIColor(hue: 0.6, saturation: 0.7, brightness: 0.5, alpha: 1.0)

    let colorWaitingForUpdate = UIColor.lightGray    // Color for 'outdated' fields, waiting for update.
    let colorLabelNormal = UIColor.white             // Normal label.
    let colorLabelAlert = UIColor.yellow             // Alert message.
    let colorLabelCopiedToClipboard = UIColor(hue: 0.35, saturation: 0.6, brightness: 0.8, alpha: 1.0)

    let zoomFactor = 2.5                            // Factor for zoom in/out.

    let metersPerDegreeLat          = (6378137.0 * 2.0 * 3.141592654) / 360.0
    let metersPerDegreeLonAtEquator = (6356752.3 * 2.0 * 3.141592654) / 360.0

    let spanInit = 8.0                              // Initial zoom, "country level".
    let spanZoomedIn = 0.003                        // Zoomed in, after double tap.
    let spanZoomedInMax = 0.0005                    // Zoomed in max.
    let spanZoomedOutMax = 175.0                    // Zoomed out max.

    let scheduleUpdateLocationsSecs = 120.0         // Switch on update locations every x secs.
    let distanceFilterMeters = 10000.0              // Not interested in local position updates.

    let limitReverseGeocodingSecs = 1.0             // Limit webservice API's to no
    let limitMapcodeLookupSecs = 1.0                // more than x requests per second.

    #if DEBUG
        let limitSwitchToOnlineAPISecs = 10.0       // Switch back to online API every x secs.
    #else
        let limitSwitchToOnlineAPISecs = 30.0
    #endif

    let mapcodeRegexWithOptionalCountryCode = try! NSRegularExpression(    // Pattern to match mapcodes: XXx[-XXx] XXxxx.XXxx[-Xxxxxxxx]

        // _______START_[' ']XXx____________________[___-_XXx______________________]' '___XXxxx____________.__XXxx___________[___-_Xxxxxxxx_________][' ']END
        pattern: "\\A\\s*(?:[a-zA-Z][a-zA-Z0-9]{1,2}(?:[-][a-zA-Z][a-zA-Z0-9]{1,2})?\\s+)?[a-zA-Z0-9]{2,5}[.][a-zA-Z0-9]{2,4}(?:[-][a-zA-Z0-9]{1,8})?\\s*\\Z",
        options: [])

    let mapcodeRegexWithCountryName = try! NSRegularExpression(            // Pattern to match mapcodes: X[x...] XXxxx.XXxx[-Xxxxxxxx]

        // _______START_[' ']X[x...__________]__' '___XXxxx________.__XXxx____________[___-_Xxxxxxxx_________][' ']END
        pattern: "\\A\\s*(([a-zA-Z][a-zA-Z]*\\s+)+)[a-zA-Z0-9]{2,5}[.][a-zA-Z0-9]{2,4}(?:[-][a-zA-Z0-9]{1,8})?\\s*\\Z",
        options: [])

    let keySendUserFeedback = "keySendUserFeedback"     // Use online API or onboard library.
    let keyVersionBuild = "keyVersionBuild"             // Version and build (for what's new).
    let keyPrevVersionBuild = "keyPrevVersionBuild"     // Previous one.

    let territoryInternationalAlphaCode = "AAA"     // Territory code for international context.
    let territoryInternationalFullName = "Earth"    // Territory full name for international context.

    let alphaEnabled: CGFloat = 1.0                 // Transparency of enabled button.
    let alphaDisabled: CGFloat = 0.0                // Transparency of disabled button.
    let alphaInvisible: CGFloat = 0.0               // Transparency hidden button.

    let resetLabelsAfterSecs = 5.0                  // Reset coordinate labels after copy to clipboard.
    let keyboardMinimumDistance: CGFloat = 4.0      // Default distance to bottom.

    var movementDistanceAddress: CGFloat = 0.0              // Distance to move screen up/down when typing.
    var movementDistanceCoordinate: CGFloat = 0.0           // These vars should be considered constants.
    let iPhoneMovementDistanceAddress: CGFloat = 125.0      // The movement distance is set once to either
    let iPhoneMovementDistanceCoordinate: CGFloat = 250.0   // iPhone or iPad movement.
    let iPadMovementDistanceAddress: CGFloat = 270.0
    let iPadMovementDistanceCoordinate: CGFloat = 400.0

    // Texts in dialogs.
    let textNoTerritoriesFound = "No territories found"
    let textLoadingTerritories = "Loading territories..."
    let textNoInternet = "No internet connection?"

    // Labels.
    let textTerritorySingle = "Territory"
    let textTerritoryXOfY = "Territory %i of %i"
    let textMapcodeSingle = "Mapcode (tap to copy)"
    let textMapcodeFirstOfN = "Mapcode"
    let textMapcodeXOfY = "Alternative %i"
    let textLatLabel = "Latitude (Y)"
    let textLonLabel = "Longitude (X)"
    let textCopiedToClipboard = "Copied to clipboard"
    let textAddressLabel = "Enter address or mapcode"
    let textWrongAddress = "Cannot find: "
    let textWrongMapcode = "Incorrect mapcode: "
    let textIndicatorOnlineAPI = ""
    let textIndicatorOfflineLibrary = "."

    // Special mapcodes.
    let longestMapcode = "MX-GRO MWWW.WWWW"
    let mostMapcodesCoordinate = CLLocationCoordinate2D(latitude: 52.0505, longitude: 113.4686)
    let mostMapcodesCoordinateCount = 21

    /**
     * Global state.
     */

    let showAlternatives: Bool = false                  // Show alternative mapcodes next to shortest one, or not.
    var useOnlineAPI: Bool = true                       // Currently using online API, or onboard library.
    var sendUserFeedback: Bool = true                   // Allowed to use online API at all, or not (privacy setting).

    // Provide a sensible screen if no user location is available (rather than mid Pacific).
    var mapcodeLocation = CLLocationCoordinate2D(latitude: 52.373293, longitude: 4.893718)

    var waitingForFirstLocationSinceStarted = true  // First location is different: auto-move to it.
    var moveMapToUserLocation = false               // True if map should auto-move to user location.

    var undoTextFieldEdit: String!                  // Undo edits if something went wrong.
    var mapChangedFromUserInteraction = false       // True if map was panned by user, rather than auto-move.

    var allMapcodes = [String]()                    // List of all mapcodes for current location (cannot be empty).
    var currentMapcodeIndex = 0                     // Index of current alternative; 0 = shortest, last = int'l.

    var allContexts = [String]()                    // List of all contexts for current location (can be empty).
    var currentContextIndex = 0                     // Index of current context.

    var territoryFullNames = [String: String]()     // List of territory alpha codes and full names. Can be empty.
    var territoryFullNamesFetched = false           // True if obtained or obtaining from server.

    var queuedCoordinateForReverseGeocode: CLLocationCoordinate2D!  // Queue of 1, for periodic rev. geocoding. Nil if none.
    var queuedCoordinateForMapcodeLookup: CLLocationCoordinate2D!   // Queue of 1, for mapcode lookup. Nil if none.

    var prevQueuedCoordinateForReverseGeocode: CLLocationCoordinate2D!  // Keep previous one, to skip new one if we can.
    var prevQueuedCoordinateForMapcodeLookup: CLLocationCoordinate2D!   // Ditto.

    var prevTimeForReverseGeocodeSecs: TimeInterval = 0.0   // Last time a request was made, to limit number of requests
    var prevTimeForMapcodeLookupSecs: TimeInterval = 0.0    // but react immediately after time of inactivity.

    var timerReverseGeocoding : Timer?              // Timer to schedule/limit reverse geocoding.
    var timerLocationUpdates : Timer?               // Timer to schedule/limit location updates.
    var timerSwitchToOnlineAPI : Timer?             // Timer to switch back to online API.
    var timerResetLabels : Timer?                   // Timer to reset labels.

    var locationManager: CLLocationManager!         // Controls and receives location updates.

    // @formatter:on

    /**
     * Errors that may be thrown when talking to an API.
     */

    enum ApiError: Error {
        case apiReturnsErrors(json: JSONValue?)
        case apiUnexpectedMessageFormat(json: JSONValue?)
    }


    /**
     * This method gets called when the view loads. It is called exactly once.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup our Map View.
        theMap.delegate = self
        theMap.mapType = MKMapType.standard
        theMap.showsUserLocation = true
        theMap.showsBuildings = true

        // Map scale only on iOS 9.0+.
        if #available(iOS 9.0, *) {
            theMap.showsScale = true
        }

        // Set initial map and zoom. Pick a decent location to start with until a real location is found.
        let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                           span: MKCoordinateSpanMake(spanInit, spanInit))
        theMap.setRegion(newRegion, animated: false)

        // Setup up delegates for text input boxes, so events are handled.
        theAddress.delegate = self
        theLat.delegate = self
        theLon.delegate = self

        // Set text fields.
        theAddressFirstLine.text = ""
        theAddress.text = ""
        theContext.text = ""
        theContextLabel.text = "Territory"
        theNextContext.isEnabled = false
        theMapcode.text = ""
        theMapcodeLabel.text = "Mapcode"
        theNextMapcode.isEnabled = false
        theNextMapcode.alpha = alphaInvisible
        theLat.text = ""
        theLon.text = ""
        theOnlineAPIIndicator.text = textIndicatorOnlineAPI

        // Work-around to move screen sufficiently high on iPad.
        if UIDevice().model.contains("iPad") {
            movementDistanceAddress = iPadMovementDistanceAddress
            movementDistanceCoordinate = iPadMovementDistanceCoordinate
        } else {
            movementDistanceAddress = iPhoneMovementDistanceAddress
            movementDistanceCoordinate = iPhoneMovementDistanceCoordinate
        }

        // Recognize 1 or 2 taps on map.
        let tapMap1 = UITapGestureRecognizer(target: self, action: #selector(handleMapTap1))
        theMap.addGestureRecognizer(tapMap1)

        let tapMap2 = UITapGestureRecognizer(target: self, action: #selector(handleMapTap2))
        tapMap2.numberOfTapsRequired = 2
        theMap.addGestureRecognizer(tapMap2)

        // Recognize 1 tap on mapcode.
        let tapMapcode = UITapGestureRecognizer(target: self, action: #selector(handleCopyMapcodeTap))
        theMapcode.addGestureRecognizer(tapMapcode)

        // Recognize 1 tap on latitude.
        let tapLatitude = UITapGestureRecognizer(target: self, action: #selector(handleCopyLatitudeLongitudeTap))
        theLatLabel.addGestureRecognizer(tapLatitude)

        // Recognize 1 tap on longitude.
        let tapLongitude = UITapGestureRecognizer(target: self, action: #selector(handleCopyLatitudeLongitudeTap))
        theLonLabel.addGestureRecognizer(tapLongitude)

        // Recognize 1 tap on context, context label and mapcode label
        let tapContextLabel = UITapGestureRecognizer(target: self, action: #selector(handleNextContextTap))
        theContextLabel.addGestureRecognizer(tapContextLabel)
        let tapContext = UITapGestureRecognizer(target: self, action: #selector(handleNextContextTap))
        theContext.addGestureRecognizer(tapContext)

        if showAlternatives {
            let tapMapcodeLabel = UITapGestureRecognizer(target: self, action: #selector(handleNextMapcodeTap))
            theMapcodeLabel.addGestureRecognizer(tapMapcodeLabel)
        } else {
            let tapMapcodeLabel = UITapGestureRecognizer(target: self, action: #selector(handleCopyMapcodeTap))
            theMapcodeLabel.addGestureRecognizer(tapMapcodeLabel)
        }

        // Subscribe to notification of keyboard show/hide.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.keyboardNotification(_:)),
                                               name: NSNotification.Name.UIKeyboardWillChangeFrame,
                                               object: nil)

        // Switch to online API or onboard library.
        let defaults = UserDefaults.standard
        defaults.set(useOnlineAPI, forKey: keySendUserFeedback)
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let build = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
        let versionBuild = "\(version) (\(build))"
        defaults.set(versionBuild, forKey: keyVersionBuild)
        switchToOnlineAPI(online: useOnlineAPI)

        // Get territory names.
        fetchTerritoryNames()

        // Setup our Location Manager. Only 1 location update is requested when the user presses
        // the "Find My Location" button. Updates are switched off immediately after that. Only
        // once every couple of minutes it is switched on for a single event again (or finding your
        // position would take longer or be less accurate). The large distance filter causes the
        // code not be called for local udpates, as that might lead to more REST calls.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilterMeters
        locationManager.requestWhenInUseAuthorization()     // Ask for permission - may show dialog.
        locationManager.startUpdatingLocation()             // Try to get the first location.

        // Show the current lat/lon and queue webservice calls for the location.
        showLatLon(mapcodeLocation)
        queueUpdateForMapcode(mapcodeLocation)
        queueUpdateForAddress(mapcodeLocation)

        // Schedule periodic updates for reverse geocoding and Mapcdode REST API requests.
        timerReverseGeocoding = Timer.scheduledTimer(
                timeInterval: limitReverseGeocodingSecs, target: self,
                selector: #selector(periodicCheckToUpdateAddress),
                userInfo: nil, repeats: true)

        timerReverseGeocoding = Timer.scheduledTimer(
                timeInterval: limitMapcodeLookupSecs, target: self,
                selector: #selector(periodicCheckToUpdateMapcode),
                userInfo: nil, repeats: true)

        timerSwitchToOnlineAPI = Timer.scheduledTimer(
            timeInterval: limitSwitchToOnlineAPISecs, target: self,
            selector: #selector(periodicSwitchToOnlineAPI),
            userInfo: nil, repeats: true)
    }


    /**
     * This gets called when the controlled is exited.
     */
    deinit {
        NotificationCenter.default.removeObserver(self)
    }


    /**
     * This method gets called whenever the keyboard is about to show/hide. Nice solution from:
     * http://stackoverflow.com/questions/25693130/move-textfield-when-keyboard-appears-swift
     */
    @objc func keyboardNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNumber = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNumber?.uintValue ?? UIViewAnimationOptions().rawValue
            let animationCurve: UIViewAnimationOptions = UIViewAnimationOptions(rawValue: animationCurveRaw)
            if endFrame?.origin.y >= UIScreen.main.bounds.size.height {
                self.keyboardHeightLayoutConstraint?.constant = keyboardMinimumDistance
            } else {
                self.keyboardHeightLayoutConstraint?.constant = endFrame?.size.height ?? keyboardMinimumDistance
            }
            UIView.animate(withDuration: duration,
                           delay: TimeInterval(0),
                           options: animationCurve,
                           animations: { self.view.layoutIfNeeded() },
                           completion: nil)
        }
    }


    /**
     * This method gets called when the view is displayed.
     */
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Show initial what's new dialog (if this is a new version).
        showStartUpText()
    }


    /**
     * This method presents the 'What's new" box.
     */
    func showStartUpText() {
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let build = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
        let versionBuild = "\(version) (\(build))"

        let defaults = UserDefaults.standard
        let prevVersionBuild = defaults.string(forKey: keyPrevVersionBuild)

        // Update settings.
        defaults.setValue(versionBuild, forKey: keyPrevVersionBuild)

        // Check if the app was updated.
        if prevVersionBuild == nil {
            self.showAbout(self)
        } else if prevVersionBuild != versionBuild {
            self.showAlert("What's New", message: "\(versionBuild):" + textWhatsNew, button: "Dismiss")
        } else {
            // No message needed.
        }
    }


    /**
     * This method gets called when the "info" icon is pressed.
     */
    @IBAction func showAbout(_ sender: AnyObject) {
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let build = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
        self.showAlert("Mapcode \(version) (\(build))", message: textAbout, button: "Dismiss")
    }


    /**
     * This gets called if the "share" button gets pressed.
     */
    @IBAction func shareButtonClicked(_ sender: UIButton) {
        let mapcode = "Mapcode: " + (theMapcode.text ?? "")
        let address = "Address: " + (theAddress.text ?? "")
        let mapImage = captureMapView(theMap, title: mapcode)
        let footer = "Visit http://mapcode.com to find out more about Mapcodes."
        let objectsToShare = [mapcode, address, mapImage, "", footer] as [Any]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        activityVC.setValue(mapcode, forKey: "subject")
        activityVC.excludedActivityTypes = [UIActivityType.airDrop, UIActivityType.addToReadingList]
        activityVC.popoverPresentationController?.sourceView = sender
        self.present(activityVC, animated: true, completion: nil)
    }


    /**
     * Helper method to check if a gesture recognizer was used.
     */
    func mapViewRegionDidChangeFromUserInteraction() -> Bool {
        let view = self.theMap.subviews[0]

        // Look through gesture recognizers to determine whether this region change is from user interaction.
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if (recognizer.state == UIGestureRecognizerState.began) || (recognizer.state == UIGestureRecognizerState.ended) {
                    return true
                }
            }
        }
        return false
    }


    /**
     * Delegate method to record if the map change was by user interaction.
     */
    func mapView(_ mapView: MKMapView,
                 regionWillChangeAnimated animated: Bool) {
        mapChangedFromUserInteraction = mapViewRegionDidChangeFromUserInteraction()
    }


    /**
     * Delegate method gets called whenever a location change is detected.
     */
    func mapView(_ mapView: MKMapView,
                 regionDidChangeAnimated animated: Bool) {

        // Stop auto-move, we don't want to keep auto-moving.
        moveMapToUserLocation = false
        if mapChangedFromUserInteraction {
            // Update fields.
            mapcodeLocation = mapView.centerCoordinate
            showLatLon(mapcodeLocation)
            queueUpdateForMapcode(mapcodeLocation)
            queueUpdateForAddress(mapcodeLocation)
        } else {
            // Fields were already updated, this map movement is a result of that.
        }
    }


    /**
     * Gesture recognizer: this method gets called when the user taps the map once.
     */
    @objc func handleMapTap1(_ gestureRecognizer: UITapGestureRecognizer) {

        // Resign keyboard form text field when user taps map.
        self.view.endEditing(true)

        // Don't auto-zoom to user location anymore.
        waitingForFirstLocationSinceStarted = false

        // Get location of tap.
        let location = gestureRecognizer.location(in: theMap)
        mapcodeLocation = theMap.convert(location, toCoordinateFrom: theMap)

        // Set map center and update fields. Do not limit zoom level.
        theMap.setCenter(mapcodeLocation, animated: true)

        // The map view will move and consequently fields get updated by regionDidChangeAnimated.
        showLatLon(mapcodeLocation)
        queueUpdateForMapcode(mapcodeLocation)
        queueUpdateForAddress(mapcodeLocation)
    }


    /**
     * Gesture recognizer: this method gets called when the user taps the map twice. Mind you:
     * The first tap has already been handled by the "tap once" recognizer.
     */
    @objc func handleMapTap2(_ gestureRecognizer: UITapGestureRecognizer) {

        // Auto zoom-in on lat tap. No need to update fields - single tap has already been handled.
        let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                           span: MKCoordinateSpanMake(spanZoomedIn, spanZoomedIn))
        theMap.setRegion(newRegion, animated: true)
    }


    /**
     * Gesture recognizer: this method gets called when the user taps the mapcode.
     */
    @objc func handleCopyMapcodeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        UIPasteboard.general.string = theMapcode.text
        theMapcodeLabel.textColor = colorLabelCopiedToClipboard
        theMapcodeLabel.text = textCopiedToClipboard
        scheduleResetLabels()
    }


    /**
     * Gesture recognizer: this method gets called when the user taps the latitude.
     */
    @objc func handleCopyLatitudeLongitudeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        // Resign keyboard form text field when user taps map.
        self.view.endEditing(true)

        UIPasteboard.general.string = theLat.text! + "," + theLon.text!
        theLatLabel.textColor = colorLabelCopiedToClipboard
        theLatLabel.text = textCopiedToClipboard
        theLonLabel.textColor = colorLabelCopiedToClipboard
        theLonLabel.text = textCopiedToClipboard
        scheduleResetLabels()
    }


    /**
     * This method schedules a reset of the labels.
     */
    func scheduleResetLabels() {
        DispatchQueue.main.async {
            if self.timerResetLabels != nil {
                self.timerResetLabels!.invalidate()
            }
            self.timerResetLabels = Timer.scheduledTimer(
                timeInterval: self.resetLabelsAfterSecs, target: self,
                selector: #selector(self.ResetLabels),
                userInfo: nil, repeats: false)
        }
    }


    /**
     * This method reset the latitude and longitude labels to their default values.
     */
    @objc func ResetLabels() {

        // Update coordinate labels.
        theAddressLabel.textColor = colorLabelNormal
        theAddressLabel.text = textAddressLabel
        theLatLabel.textColor = colorLabelNormal
        theLatLabel.text = textLatLabel
        theLonLabel.textColor = colorLabelNormal
        theLonLabel.text = textLonLabel

        // Update mapcode label.
        updateMapcodeLabel()
    }


    /**
     * This gets called whenever the use switches between nromal and hybrid map types.
     */
    @IBAction func segmentedControlAction(_ sender: UISegmentedControl!) {
        switch sender.selectedSegmentIndex {
        case 0:
            theMap.mapType = .standard

        default:
            theMap.mapType = .hybrid
        }
    }


    /**
     * This method gets called when user starts editing a text field. Keep the previous
     * value for undo. Careful though: the undo text is shared for all fields.
     */
    @IBAction func beginEdit(_ textField: UITextField) {
        DispatchQueue.main.async {
            self.undoTextFieldEdit = textField.text
            textField.selectAll(self)
        }
    }


    /**
     * This method gets called when user starts editing the address field. This needs to
     * clear the first address line as well.
     */
    @IBAction func beginEditAddress(_ textField: UITextField) {
        DispatchQueue.main.async {
            self.theAddressFirstLine.text = ""
        }
        beginEdit(textField)
    }


    /**
     * Delegate method gets called when the Return key is pressed in a text edit field.
     */
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        // Hide keyboard.
        self.view.endEditing(true)

        // Do not process empty fields.
        if (textField.text == nil) || (textField.text?.isEmpty)! {
            // Restore contents of field.
            textField.text = undoTextFieldEdit
            return false
        }

        // Don't auto-zoom to user location anymore.
        waitingForFirstLocationSinceStarted = false

        // Clean up the input a bit.
        let input = trimAllSpace(theAddress.text!).replacingOccurrences(of: "\\s+",
                                                                        with: " ",
                                                                        options: NSString.CompareOptions.regularExpression,
                                                                        range: nil)
        // Determine which field we're in.
        switch textField.tag {
        case theAddress.tag:

            // Check if the user entered a mapcode instead of an address.
            let matchesMapcodeWithOptionalCountryCode = mapcodeRegexWithOptionalCountryCode.matches(
                    in: input, options: [],
                    range: NSRange(location: 0, length: input.count))
            if matchesMapcodeWithOptionalCountryCode.count == 1 {
                debug(DEBUG, msg: "textFieldShouldReturn: Entered mapcode with optional country code, mapcode=\(input)")
                mapcodeWasEntered(input, context: nil)
            } else {
                let matchesMapcodeWithCountryName = mapcodeRegexWithCountryName.matches(
                        in: input, options: [],
                        range: NSRange(location: 0, length: input.count))
                if matchesMapcodeWithCountryName.count == 1 {
                    let range = input.range(of: " ", options: .backwards)
                    let country = String(input[input.startIndex..<(range?.lowerBound)!])
                    let mapcode = String(input[(range?.upperBound)!..<(input.endIndex)])
                    debug(DEBUG, msg: "textFieldShouldReturn: Entered mapcode with country name, country=\(country) mapcode=\(mapcode)")
                    mapcodeWasEntered(mapcode, context: country)
                } else {
                    debug(DEBUG, msg: "textFieldShouldReturn: Entered address, address=\(theAddress.text!)")
                    addressWasEntered(input)
                }
            }

        case theLat.tag:

            // Check if we can actually convert this to a double.
            if Double(theLat.text!) != nil {
                coordinateWasEntered(theLat.text!, longitude: theLon.text!)
            } else {
                theLat.text = undoTextFieldEdit
            }

        case theLon.tag:

            // Check if we can actually convert this to a double.
            if Double(theLon.text!) != nil {
                coordinateWasEntered(theLat.text!, longitude: theLon.text!)
            } else {
                theLon.text = undoTextFieldEdit
            }

        default:
            debug(ERROR, msg: "textFieldShouldReturn: Unknown text field, tag=\(textField.tag)")
        }
        return false
    }


    /**
     * This method gets called when an address was entered.
     */
    func addressWasEntered(_ address: String) {

        // Geocode address.
        debug(INFO, msg: "addressWasEntered: Call Forward Geocoding API: \(address)")
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address, completionHandler: {
            (placemarks, error) -> Void in

            if (error != nil) || (placemarks == nil) || (placemarks?.first == nil) || (placemarks?.first?.location == nil) {
                self.debug(self.INFO, msg: "addressWasEntered: Geocode failed, address=\(address), error=\(error!))")

                DispatchQueue.main.async {
                    self.theAddressLabel.textColor = self.colorLabelAlert
                    self.theAddressLabel.text = "\(self.textWrongAddress) \(address.uppercased())"

                    // Force call to reset address field; need to do a new reverse geocode as previous text is lost.
                    self.prevQueuedCoordinateForReverseGeocode = nil
                    self.queueUpdateForAddress(self.mapcodeLocation)

                    // Reset error label after some time.
                    self.scheduleResetLabels()
                }
            } else {
                // Found location; determine coordinate and proper zoom level.
                let first = (placemarks?.first)!
                let coordinate = first.location!.coordinate
                let region = first.region as! CLCircularRegion

                // Add 50% slack around the edges.
                let spanLat = min(self.spanZoomedOutMax,
                                  max(self.spanZoomedInMax,
                                      1.5 * region.radius / self.metersPerDegreeLat))
                let spanLon = min(self.spanZoomedOutMax,
                                  max(self.spanZoomedInMax,
                                      1.5 * region.radius / self.metersPerDegreeLonAtLan(coordinate.latitude)))

                DispatchQueue.main.async {
                    // Update location.
                    self.mapcodeLocation = coordinate
                    let newRegion = MKCoordinateRegion(center: coordinate,
                                                       span: MKCoordinateSpanMake(spanLat, spanLon))
                    self.theMap.setRegion(newRegion, animated: false)
                    self.showLatLon(coordinate)
                    self.queueUpdateForMapcode(coordinate)
                    self.queueUpdateForAddress(coordinate)
                }
            }
        })
    }


    /**
     * This method gets called when a mapcode was entered.
     */
    func mapcodeWasEntered(_ mapcode: String, context: String?) {

        // Prefix previous territory for local mapcodes.
        var fullMapcode = trimAllSpace(mapcode)
        if ((context == nil) && fullMapcode.count < 10) && !fullMapcode.contains(" ") && !allContexts.isEmpty {
            fullMapcode = "\(allContexts[currentContextIndex]) \(fullMapcode)"
        }

        // Use REST service or onboard client library.
        switchToOnlineAPI(online: useOnlineAPI)
        if useOnlineAPI {

            // Create URL for REST API call to get mapcodes.
            let encodedMapcode = fullMapcode.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!

            var url = "\(host)/mapcode/coords/\(encodedMapcode)?client=\(client)&allowLog=\(allowLog)"
            if context != nil {
                let encodedContext = context!.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                url = url + "&context=\(encodedContext)"
            }
            guard let rest = RestController.make(urlString: url) else {
                debug(ERROR, msg: "mapcodeWasEntered: Bad URL, url=\(url)")
                return
            }

            // Get coordinate.
            debug(INFO, msg: "mapcodeWasEntered: Call Mapcode API: url=\(url)")
            rest.get {
                result, httpResponse in
                do {
                    let json = try result.value()
                    let status = httpResponse?.statusCode
                    if (status != 200) {
                        self.debug(self.INFO, msg: "mapcodeWasEntered: Incorrect mapcode=\(mapcode)")
                        DispatchQueue.main.async {
                            // Show error in label.
                            self.theAddressLabel.textColor = self.colorLabelAlert
                            self.theAddressLabel.text = "\(self.textWrongMapcode) \(mapcode.uppercased())"

                            // Reset error label after some time.
                            self.scheduleResetLabels()
                        }
                    }

                    // Check status OK
                    if (status == 200) &&
                               (json["errors"].array == nil) &&
                               (json["latDeg"].double != nil) &&
                               (json["lonDeg"].double != nil) {
                        let lat = (json["latDeg"].double)!
                        let lon = (json["lonDeg"].double)!
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                        // Update location and set map center.
                        DispatchQueue.main.async {
                            self.mapcodeLocation = coordinate
                            self.setMapCenterAndLimitZoom(coordinate, maxSpan: self.spanZoomedIn, animated: false)
                            self.showLatLon(coordinate)
                            self.queueUpdateForMapcode(coordinate)

                            // Force call.
                            self.prevQueuedCoordinateForReverseGeocode = nil
                            self.queueUpdateForAddress(coordinate)
                        }
                    } else {
                        self.debug(self.INFO, msg: "mapcodeWasEntered: Find mapcode failed, url=\(url), status=\(httpResponse!.statusCode), json=\(json)")

                        // Revert to previous address; need to call REST API because previous text is lost.
                        DispatchQueue.main.async {
                            // Force call.
                            self.prevQueuedCoordinateForReverseGeocode = nil
                            self.queueUpdateForAddress(self.mapcodeLocation)
                        }
                    }
                } catch {
                    self.debug(self.WARN, msg: "mapcodeWasEntered: API call failed, url=\(url), error=\(error)")
                    DispatchQueue.main.async {
                        // Reset to backup.
                        self.prevQueuedCoordinateForMapcodeLookup = nil
                        self.prevQueuedCoordinateForReverseGeocode = nil
                        self.queuedCoordinateForMapcodeLookup = self.mapcodeLocation
                        self.queuedCoordinateForReverseGeocode = self.mapcodeLocation
                        self.theAddress.text = ""
                        self.theAddressFirstLine.text = self.textNoInternet

                        // Switch to using the library in case of a network error.
                        self.switchToOnlineAPI(online: false)
                    }
                }
            }
        } else {

            // Use onboard mapcode library to decode a mapcode.
            let territory = getTerritoryCode(context, TERRITORY_NONE)
            var lat: Double = 0.0
            var lon: Double = 0.0
            let mapcodeError = decodeMapcodeToLatLonUtf8(&lat, &lon, fullMapcode, territory, nil)
            if mapcodeError == ERR_OK {
                debug(INFO, msg: "mapcodeWasEntered: Decode using onboard mapcode library, fullMapcode=\(fullMapcode), territory=\(territory), lat=\(lat), lon=\(lon)")
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                // Update location and set map center.
                DispatchQueue.main.async {
                    self.mapcodeLocation = coordinate
                    self.setMapCenterAndLimitZoom(coordinate, maxSpan: self.spanZoomedIn, animated: false)
                    self.showLatLon(coordinate)
                    self.queueUpdateForMapcode(coordinate)

                    // Force call.
                    self.prevQueuedCoordinateForReverseGeocode = nil
                    self.queueUpdateForAddress(coordinate)
                }
            } else {
                debug(INFO, msg: "mapcodeWasEntered: Cannot decode mapcode, fullMapcode=\(fullMapcode), territory=\(territory), mapcodeError=\(mapcodeError)")

                // Revert to previous address; need to call again because previous text is lost.
                DispatchQueue.main.async {
                    // Force call.
                    self.prevQueuedCoordinateForReverseGeocode = nil
                    self.queueUpdateForAddress(self.mapcodeLocation)
                }
            }
        }
    }


    /**
     * This method gets called when the lat or lon box was edited.
     */
    func coordinateWasEntered(_ latitude: String, longitude: String) {
        var lat = Double(latitude)
        var lon = Double(longitude)
        if (lat != nil) && (lon != nil) {
            // Limit range.
            lat = truncLatitude(lat!)
            lon = truncLongitude(lon!)

            // Update location.
            mapcodeLocation = CLLocationCoordinate2D(latitude: lat!, longitude: lon!)
            setMapCenterAndLimitZoom(mapcodeLocation, maxSpan: spanZoomedIn, animated: false)
            showLatLon(mapcodeLocation)
            queueUpdateForMapcode(mapcodeLocation)
            queueUpdateForAddress(mapcodeLocation)
        }
    }


    /**
     * Fetch all territory names.
     */
    func fetchTerritoryNames() {

        // Using onboard mapcode library to fetch territory names.
        debug(INFO, msg: "fetchTerritoryNames: Using onboard mapcode library to fetch territory names.")

        // Declare UTF8 buffer.
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(_MAX_TERRITORY_FULLNAME_UTF8_LEN + 1))
        buffer.initialize(to: 0, count: Int(_MAX_TERRITORY_FULLNAME_UTF8_LEN + 1))

        // Get territories and add to our map.
        var newTerritoryFullNames = [String: String]()
        var territory = Territory.init(_TERRITORY_MIN.rawValue + 1)
        while territory != _TERRITORY_MAX {

            // Get alpha code.
            getTerritoryIsoName(buffer, territory, 0)
            let alphaCode = String.init(cString: buffer)

            // Get full name.
            getFullTerritoryNameEnglish(buffer, territory, 0)
            let fullName = String.init(cString: buffer)

            newTerritoryFullNames[alphaCode] = fullName
            territory = Territory.init(territory.rawValue + 1)
        }

        // Pass territories to main and update context field.
        territoryFullNames = newTerritoryFullNames
        updateContext()
    }


    /**
     * This method gets called when the "find here" icon is pressed.
     */
    @IBAction func findMyLocation(_ sender: AnyObject) {
        // Invalidate timer: cancels next scheduled update. Will automatically be-rescheduled.
        DispatchQueue.main.async {
            if self.timerLocationUpdates != nil {
                self.timerLocationUpdates!.invalidate()
            }

        }

        // Set auto-move to user location and start collecting updates and update map.
        moveMapToUserLocation = true

        // Turn on location updates.
        turnOnLocationManagerUpdates()
    }


    /**
     * This method gets called when the "zoom in" icon is pressed.
     */
    @IBAction func zoomIn(_ sender: AnyObject) {
        var region = theMap.region
        let lat = region.span.latitudeDelta / zoomFactor
        let lon = region.span.longitudeDelta / zoomFactor
        region.span.latitudeDelta = max(spanZoomedInMax, lat)
        region.span.longitudeDelta = max(spanZoomedInMax, lon)
        theMap.setRegion(region, animated: true)
    }


    /**
     * This method gets called when the "zoom out" icon is pressed.
     */
    @IBAction func zoomOut(_ sender: AnyObject) {
        var region = theMap.region
        let lat = region.span.latitudeDelta * zoomFactor
        let lon = region.span.longitudeDelta * zoomFactor
        region.span.latitudeDelta = min(spanZoomedOutMax, lat)
        region.span.longitudeDelta = min(spanZoomedOutMax, lon)
        theMap.setRegion(region, animated: true)
    }


    /**
     * This method gets called when the user taps the context label, which means: next item.
     */
    @objc func handleNextContextTap(_ gestureRecognizer: UITapGestureRecognizer) {

        // Resign keyboard form text field when user taps map.
        self.view.endEditing(true)

        nextContext(self)
    }


    /**
     * This method gets called when the "toggle mapcode" button is pressed.
     */
    @IBAction func nextContext(_ sender: AnyObject) {

        // Move to next alternative next time we press the button.
        if allContexts.isEmpty {
            // There are no contexts. Reset index for next time there are contexts.
            currentContextIndex = 0
        } else {
            // Wrap when counting.
            currentContextIndex = (currentContextIndex + 1) % allContexts.count
        }

        // Reset mapcode index when changing context.
        currentMapcodeIndex = 0

        // Show current mapcode.
        updateContext()

        // Show mapcodes for context.
        updateMapcode()
    }


    /**
     * This method gets called when the user taps the mapcode label, which means: next item.
     */
    @objc func handleNextMapcodeTap(_ gestureRecognizer: UITapGestureRecognizer) {

        // Resign keyboard form text field when user taps map.
        self.view.endEditing(true)

        nextMapcode(self)
    }


    /**
     * This method gets called when the "toggle mapcode" button is pressed.
     */
    @IBAction func nextMapcode(_ sender: AnyObject) {

        // Move to next alternative next time we press the button.
        currentMapcodeIndex += 1

        // Show current mapcode, no need to update context field.
        updateMapcode()
    }


    /**
     * This method returns an array of all mapcodes for a specific territory.
     */
    func getMapcodesForTerritory(_ territory: String!) -> [String] {
        var selection = [String]()
        for m in allMapcodes {
            // Add the code if the territory is OK, or the context is international and
            // it's the international code.
            if territory == nil {
                if !m.contains(" ") {
                    selection.append(m)
                }
            } else {
                if m.starts(with: territory) {
                    selection.append(m)
                }
            }
        }
        return selection
    }


    /**
     * This method updates the mapcode and mapcode label fields.
     */
    func updateMapcode() {

        // Selected context.
        var context: String!
        if !allContexts.isEmpty && (currentContextIndex < (allContexts.count - 1)) {
            context = allContexts[currentContextIndex]
        }

        // Add mapcodes in territory only.
        var selection = getMapcodesForTerritory(context)

        // Limit index to a place in this list.
        let count = selection.count
        if currentMapcodeIndex >= count {
            currentMapcodeIndex = 0
        }

        // Get the mapcode from this selection.
        let mapcode = selection[currentMapcodeIndex]

        // Set the mapcode text.
        let attributedText = NSMutableAttributedString(string: mapcode)

        // Set defaults.
        let fullRange = NSMakeRange(0, mapcode.distance(from: mapcode.startIndex, to: mapcode.endIndex))

        // Set color of mapcode itself.
        attributedText.addAttributes([NSAttributedStringKey.foregroundColor: colorMapcode], range: fullRange)

        // Set font size, reduce size for really large mapcodes.
        var fontSize = mapcodeCodeFontSize
        if mapcode.count >= longestMapcode.count {
            fontSize = mapcodeCodeFontSizeSmall
        }
        attributedText.addAttributes([NSAttributedStringKey.font: UIFont(name: mapcodeCodeFont, size: fontSize)!], range: fullRange)
        attributedText.addAttributes([NSAttributedStringKey.kern: mapcodeFontKern], range: fullRange)

        // If the code has a territory, make it look different.
        let index = mapcode.index(of: Character(" "))
        if index != nil {
            let n = mapcode.distance(from: mapcode.startIndex, to: index!)
            attributedText.addAttributes([NSAttributedStringKey.foregroundColor: colorTerritoryPrefix], range: NSMakeRange(0, n))
            attributedText.addAttributes([NSAttributedStringKey.font: UIFont(name: mapcodeTerritoryFont, size: mapcodeTerritoryFontSize)!], range: NSMakeRange(0, n))
        } else {
            // If the code has no territory, it is the international code.
            attributedText.addAttributes([NSAttributedStringKey.font: UIFont(name: mapcodeInternationalFont, size: mapcodeInternationalFontSize)!], range: fullRange)
        }
        theMapcode.attributedText = attributedText
        updateMapcodeLabel()
    }


    /**
     * This method updates the mapcode label text.
     */
    func updateMapcodeLabel() {

        // Bail out if the contexts weren't read yet.
        if allContexts.count == 0 {
            return
        }

        // Set the label color.
        theMapcodeLabel.textColor = colorLabelNormal

        // Set the mapcode label text. There's always a mapcode.
        let count = getMapcodesForTerritory(allContexts[currentContextIndex]).count
        if !showAlternatives {
            theNextMapcode.isEnabled = false
            theNextMapcode.alpha = alphaInvisible
            theMapcodeLabel.text = textMapcodeSingle
        } else if count <= 1 {
            theNextMapcode.isEnabled = false
            theNextMapcode.alpha = alphaDisabled
            theMapcodeLabel.text = textMapcodeSingle
        } else {
            theNextMapcode.isEnabled = true
            theNextMapcode.alpha = alphaEnabled
            if currentMapcodeIndex == 0 {
                theMapcodeLabel.text = String(format: textMapcodeFirstOfN, count - 1)
            } else {
                theMapcodeLabel.text = String(format: textMapcodeXOfY, currentMapcodeIndex, count - 1)
            }
        }
    }


    /**
     * This method udpates the context and context label fields.
     */
    func updateContext() {

        // Get current context.
        var fullName: String!
        if !allContexts.isEmpty {

            // Find its full name.
            let alphaCode = allContexts[currentContextIndex]
            fullName = territoryFullNames[alphaCode]
            if fullName == nil {
                debug(INFO, msg: "updateContext: Territory not found, alphaCode=\(alphaCode)")
            }
        }

        // Check if full name was found. Normally it is only not found if either the territories were
        // not loaded yet, or there are no contexts for this location.

        if fullName == nil {
            fullName = textLoadingTerritories
        }

        // Show full name.
        let attributedText = NSMutableAttributedString(string: fullName!)
        let fullRange = NSMakeRange(0, fullName!.distance(from: fullName!.startIndex, to: fullName!.endIndex))
        attributedText.addAttributes([NSAttributedStringKey.font: UIFont(name: contextFont, size: contextFontSize)!], range: fullRange)
        theContext.attributedText = attributedText

        // Set the mapcode label text. There's always a context.
        if allContexts.count == 1 {
            theNextContext.isEnabled = false
            theNextContext.alpha = alphaDisabled
            theContextLabel.text = textTerritorySingle
        } else {
            theNextContext.isEnabled = true
            theNextContext.alpha = alphaEnabled
            theContextLabel.text = String(format: textTerritoryXOfY, currentContextIndex + 1, allContexts.count)
        }
    }


    /**
     * Update latitude and logitude fields.
     */
    func showLatLon(_ coordinate: CLLocationCoordinate2D) {

        // Update latitude and longitude, strip to microdegree precision.
        theLat.text = String(format: "%3.5f", coordinate.latitude)
        theLon.text = String(format: "%3.5f", coordinate.longitude)
    }


    /**
     * Queue reverse geocode request (to a max of 1 in the queue).
     */
    func queueUpdateForAddress(_ coordinate: CLLocationCoordinate2D) {

        // Keep only the last coordinate.
        queuedCoordinateForReverseGeocode = coordinate

        // And try immediately.
        periodicCheckToUpdateAddress()
    }


    /**
     * This method limits the calls to the Apple API to once every x secs.
     */
    @objc func periodicSwitchToOnlineAPI() {
        switchToOnlineAPI(online: true)
    }


    /**
     * This method limits the calls to the Apple API to once every x secs.
     */
    @objc func periodicCheckToUpdateAddress() {

        // Bail out if nothing changed.
        if isEqualOrNil(queuedCoordinateForReverseGeocode, prevCoordinate: prevQueuedCoordinateForReverseGeocode) {
            debug(TRACE, msg: "periodicCheckToUpdateAddress: Filtered (no change), coordinate=\(queuedCoordinateForReverseGeocode)")
            return
        }

        // Make sure we do this, even if we go back to the same coordinate (because text field is dimmed).
        prevQueuedCoordinateForReverseGeocode = nil

        // Something to do, dim current field.
        theAddress.textColor = colorWaitingForUpdate

        // Now check if we're not flooding the web service calls.
        let now = Date().timeIntervalSince1970
        let timePassed = now - prevTimeForReverseGeocodeSecs
        if timePassed < limitReverseGeocodingSecs {
            debug(TRACE, msg: "periodicCheckToUpdateAddress: Filtered (too soon), timePassed=\(timePassed)")
            return
        }

        // Update last time stamp and previous request.
        prevTimeForReverseGeocodeSecs = now
        prevQueuedCoordinateForReverseGeocode = queuedCoordinateForReverseGeocode

        // Keep coordinate local.
        let coordinate = queuedCoordinateForReverseGeocode!

        // Clear the request.
        queuedCoordinateForReverseGeocode = nil

        // Get address from reverse geocode.
        debug(INFO, msg: "periodicCheckToUpdateAddress: Call Reverse Geocoding API: \(coordinate)")
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), completionHandler: {
            (placemarks, error) -> Void in
            if error != nil {
                // Print an message to console, but don't show a user dialog (not an error).
                self.debug(self.INFO, msg: "periodicCheckToUpdateAddress: No reverse geocode info, coordinate=\(coordinate), error=\(error!.localizedDescription)")
                DispatchQueue.main.async {
                    self.theAddress.text = ""
                    self.theAddressFirstLine.text = self.textNoInternet
                }
                return
            }

            // Construct address
            if placemarks!.count > 0 {
                let pm = placemarks!.first!

                // Get address from formatted address lines. First line seems to be neighborhood or POI sometimes, however.
                var address = ""
                var addressFirstLine = ""
                if let lines = pm.addressDictionary!["FormattedAddressLines"] as! [String]! {
                    var start = 0
                    if lines.count > 3 {
                        addressFirstLine = lines.first!
                        start = 1
                    }
                    address = lines[start]
                    for line in lines.dropFirst(start + 1) {
                        address = address + "\n" + line
                    }
                    address = address.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: "\n", with: ", ")
                }

                // Update address fields.
                DispatchQueue.main.async {
                    self.theAddressFirstLine.text = addressFirstLine
                    self.theAddress.textColor = UIColor.black
                    self.theAddress.text = address
                }
            } else {
                self.debug(self.INFO, msg: "periodicCheckToUpdateAddress: No placemarks, coordinate=\(coordinate)")
            }
        })
    }


    /**
     * Queue Mapcode REST API request (to a max of 1 in the queue).
     */
    func queueUpdateForMapcode(_ coordinate: CLLocationCoordinate2D) {

        // Keep only the last coordinate.
        queuedCoordinateForMapcodeLookup = coordinate

        // And try immediately.
        periodicCheckToUpdateMapcode()
    }


    /**
     * Call Mapcode REST API to get mapcode codes from latitude, longitude.
     */
    @objc func periodicCheckToUpdateMapcode() {

        // Bail out if nothing changed.
        if isEqualOrNil(queuedCoordinateForMapcodeLookup, prevCoordinate: prevQueuedCoordinateForMapcodeLookup) {
            debug(TRACE, msg: "periodicCheckToUpdateMapcode: Filtered (no change), coordinate=\(queuedCoordinateForMapcodeLookup)")
            return
        }

        // Make sure we do this, even if we go back to the same coordinate (because text field is dimmed).
        prevQueuedCoordinateForMapcodeLookup = nil

        // Something to do, dim current field.
        theMapcode.textColor = colorWaitingForUpdate

        // Now check if we're not flooding the web service calls.
        let now = Date().timeIntervalSince1970
        let timePassed = now - prevTimeForMapcodeLookupSecs
        if timePassed < limitMapcodeLookupSecs {
            debug(TRACE, msg: "periodicCheckToUpdateMapcode: Too soon, timePassed=\(timePassed)")
            return
        }

        // Update last time stamp and previous request.
        prevTimeForMapcodeLookupSecs = now
        prevQueuedCoordinateForMapcodeLookup = queuedCoordinateForMapcodeLookup

        // Keep the coordinate local.
        let coordinate = queuedCoordinateForMapcodeLookup

        // Clear the request, keep a backup when an error occurs.
        queuedCoordinateForMapcodeLookup = nil

        // Use REST service or onboard client library.
        switchToOnlineAPI(online: useOnlineAPI)
        if useOnlineAPI {

            // Create URL for REST API call to get mapcodes, URL-encode lat/lon.
            let encodedLatLon = "\(coordinate!.latitude),\(coordinate!.longitude)".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            let url = "\(host)/mapcode/codes/\(encodedLatLon)?client=\(client)&allowLog=\(allowLog)"

            guard let rest = RestController.make(urlString: url) else {
                debug(ERROR, msg: "periodicCheckToUpdateMapcode: Bad URL, url=\(url)")
                return
            }

            // Get mapcodes from REST API.
            debug(INFO, msg: "periodicCheckToUpdateMapcode: Call Mapcode API: url=\(url)")
            rest.get {
                result, httpResponse in
                do {
                    // Get JSON response.
                    let json = try result.value()
                    let status = httpResponse?.statusCode

                    // The JSON response indicated an error, territory is set to nil.
                    if (status != 200) || (json["errors"].array != nil) {
                        throw ApiError.apiReturnsErrors(json: json["errors"])
                    }

                    // Get international mapcode (must exist).
                    if (json["international"]["mapcode"].string == nil) {
                        throw ApiError.apiUnexpectedMessageFormat(json: json)
                    }
                    let mapcodeInternational = (json["international"]["mapcode"].string)!


                    // Get shortest local mapcode (optional).
                    var mapcodeLocal = ""
                    var territoryLocal = ""
                    if json["local"]["territory"].string != nil {
                        territoryLocal = (json["local"]["territory"].string)!
                    }
                    if json["local"]["mapcode"].string != nil {
                        mapcodeLocal = (json["local"]["mapcode"].string)!
                    }

                    // Try to match existing context with 1 from the new list.
                    var prevContext: String!
                    if !self.allContexts.isEmpty {
                        prevContext = self.allContexts[self.currentContextIndex]
                    }

                    // The new index; nil means: no matching territory found yet.
                    var newContextIndex: Int!

                    // Create a new list of mapcodes and contexts.
                    var newAllMapcodes = [String]()
                    var newAllContexts = [String]()

                    // Get list of all mapcodes (must exist and must contain at least the international mapcode).
                    if (json["mapcodes"].array == nil) {
                        throw ApiError.apiUnexpectedMessageFormat(json: json)
                    }

                    // Store the list of mapcodes (must include the international mapcode).
                    let alt = (json["mapcodes"].array)!
                    if alt.count == 0 {
                        throw ApiError.apiUnexpectedMessageFormat(json: json["mapcodes"])
                    }

                    // If there are other mapcodes besides the international one, process them.
                    if alt.count >= 2 {
                        // Add the shortest one at front (which only exists if there are 2+ mapcodes).
                        newAllMapcodes.append("\(territoryLocal) \(mapcodeLocal)")
                        newAllContexts.append(territoryLocal)
                        if (prevContext != nil) && (prevContext == territoryLocal) {
                            newContextIndex = 0
                        }

                        // Add the alternatives, NOT including the international (which is last and has no territory).
                        for i in 0...alt.count - 2 {
                            // Create the full mapcode.
                            let territory = (alt[i]["territory"].string)!
                            let mapcode = (alt[i]["mapcode"].string)!

                            // Don't add the already added local mapcode (or its territory).
                            if (territory != territoryLocal) || (mapcode != mapcodeLocal) {
                                newAllMapcodes.append("\(territory) \(mapcode)")

                                // Keep the territories (no doubles).
                                if (!newAllContexts.contains(territory)) {
                                    newAllContexts.append(territory)

                                    // Update the new index only if it didn't have a value yet.
                                    if (newContextIndex == nil) && (prevContext != nil) && (prevContext == territory) {
                                        newContextIndex = newAllContexts.count - 1
                                    }
                                }
                            }
                        }
                    }

                    // Special case: Always append the international mapcode and context at the end.
                    // Do NOT match the previous context - we rather have it snap to something else than international.
                    newAllContexts.append(self.territoryInternationalAlphaCode)
                    newAllMapcodes.append(mapcodeInternational)

                    // Now, if we still didn't find a matching territory, fall back to the first one.
                    if newContextIndex == nil {
                        newContextIndex = 0
                    }

                    // Update mapcode fields on main thread.
                    DispatchQueue.main.async {
                        self.allContexts = newAllContexts
                        self.currentContextIndex = newContextIndex
                        self.allMapcodes = newAllMapcodes
                        self.currentMapcodeIndex = 0
                        self.updateContext()
                        self.updateMapcode()
                    }
                } catch {
                    self.debug(self.WARN, msg: "periodicCheckToUpdateMapcode: API call failed, url=\(url), error=\(error)")
                    DispatchQueue.main.async {
                        // Reset to backup.
                        self.prevQueuedCoordinateForMapcodeLookup = nil
                        self.prevQueuedCoordinateForReverseGeocode = nil
                        self.queuedCoordinateForMapcodeLookup = coordinate
                        self.queuedCoordinateForReverseGeocode = coordinate
                        self.theAddress.text = ""
                        self.theAddressFirstLine.text = self.textNoInternet

                        // Switch to using the library in case of a network error.
                        self.switchToOnlineAPI(online: false)
                    }
                }
            }
        } else {

            // Using onboard client library to encode a lat/lon to mapcodes.
            // Try to match existing context with 1 from the new list.
            var prevContext: String!
            if !self.allContexts.isEmpty {
                prevContext = self.allContexts[self.currentContextIndex]
            }

            // The new index; nil means: no matching territory found yet.
            var newContextIndex: Int!

            // Create a new list of mapcodes and contexts.
            var newAllMapcodes = [String]()
            var newAllContexts = [String]()

            // Use onboard mapcode library to create international mapcode.
            debug(INFO, msg: "periodicCheckToUpdateMapcode: Using onboard mapcode library to encode (\(coordinate!.latitude), \(coordinate!.longitude))")

            let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(_MAX_MAPCODE_RESULT_ASCII_LEN))
            buffer.initialize(to: 0, count: Int(_MAX_MAPCODE_RESULT_ASCII_LEN))
            var prevTerritoryLocal: String = ""
            var total: Int32 = 0;
            var i: Int32 = 0
            repeat {
                total = encodeLatLonToSelectedMapcode(buffer, coordinate!.latitude, coordinate!.longitude, TERRITORY_NONE, 0, i)
                if (total > 0) {
                    let mapcode = String.init(cString: buffer);
                    let index = mapcode.index(of: " ") ?? mapcode.endIndex;
                    if index != mapcode.endIndex {
                        let territoryLocal = String(mapcode[..<index])
                        debug(TRACE, msg: "periodicCheckToUpdateMapcode: total=\(total), i=\(i), mapcode=\(mapcode), territoryLocal=\(territoryLocal)")
                        if territoryLocal != prevTerritoryLocal {
                            newAllContexts.append(territoryLocal)

                            // Update the new index only if it didn't have a value yet.
                            if (newContextIndex == nil) && (prevContext != nil) && (prevContext == territoryLocal) {
                                newContextIndex = newAllContexts.count - 1
                            }
                            prevTerritoryLocal = territoryLocal
                        }
                    }
                    newAllMapcodes.append(mapcode)
                }
                i = i + 1
            } while (i < total)
            newAllContexts.append(self.territoryInternationalAlphaCode)

            // Now, if we still didn't find a matching territory, fall back to the first one.
            if newContextIndex == nil {
                newContextIndex = 0
            }

            // Update mapcode fields on main thread.
            DispatchQueue.main.async {
                self.allContexts = newAllContexts
                self.currentContextIndex = newContextIndex
                self.allMapcodes = newAllMapcodes
                self.currentMapcodeIndex = 0
                self.updateContext()
                self.updateMapcode()
            }
        }
    }


    /**
     * This method gets called whenever a location change is detected.
     */
    func locationManager(_ locationManager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {

        // Get new location.
        let newLocation = locations[0].coordinate

        // Set default span.
        var span = spanZoomedIn

        // If it's a valid coordinate and we need to auto-move or it's the first location, move.
        if isValidCoordinate(newLocation) {
            if waitingForFirstLocationSinceStarted || moveMapToUserLocation {
                // Update location.
                mapcodeLocation = newLocation

                // First time location ever? Override map zoom.
                if waitingForFirstLocationSinceStarted {
                    span = spanInit
                    waitingForFirstLocationSinceStarted = false
                }
                moveMapToUserLocation = false

                // Change zoom level, pretty much zoomed out.
                let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                                   span: MKCoordinateSpanMake(span, span))

                // Move without animation.
                theMap.setRegion(newRegion, animated: true)

                // Update text fields.
                showLatLon(mapcodeLocation)
                queueUpdateForMapcode(mapcodeLocation)
                queueUpdateForAddress(mapcodeLocation)
            }

            // Stop receiving updates after we get a first (decent) user location.
            locationManager.stopUpdatingLocation()

            // Schedule updating the location again in some time.
            DispatchQueue.main.async {
                if self.timerLocationUpdates != nil {
                    self.timerLocationUpdates!.invalidate()
                }
                self.timerLocationUpdates = Timer.scheduledTimer(timeInterval: self.scheduleUpdateLocationsSecs, target: self,
                                                            selector: #selector(self.turnOnLocationManagerUpdates),
                                                            userInfo: nil, repeats: false)
            }
        }
    }


    /**
     * Method to switch on the location manager updates.
     */
    @objc func turnOnLocationManagerUpdates() {
        locationManager.startUpdatingLocation()
    }


    /**
     * This method gets called when the location cannot be fetched.
     */
    func locationManager(_ locationManager: CLLocationManager,
                         didFailWithError error: Error) {

        // Code 0 is returned when during debugging anyhow.
        if (error._code != 0) {
            debug(WARN, msg: "LocationManager:didFailWithError, error=\(error)")
        }
    }


    /**
     * This method gets called when the location authorization changes.
     */
    func locationManager(_ locationManager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        debug(INFO, msg: "locationManager:didChangeAuthorizationStatus, status=\(status)")

        let allow: Bool!
        switch status {
        case CLAuthorizationStatus.authorizedWhenInUse:
            allow = true

        case CLAuthorizationStatus.authorizedAlways:
            allow = true

        default:
            allow = false
            locationManager.stopUpdatingLocation()
        }
        if allow! {
            theFindMyLocation.isEnabled = true
            theFindMyLocation.alpha = alphaEnabled
        } else {
            theFindMyLocation.isEnabled = false
            theFindMyLocation.alpha = alphaDisabled
        }
    }


    /**
     * This method gets called when the "open in maps" icon is pressed.
     */
    @IBAction func openInMapsApplication(_ sender: AnyObject) {
        openMapApplication(mapcodeLocation, name: theMapcode.text!)
    }


    /**
     * This method open the Apple Maps application.
     */
    func openMapApplication(_ coordinate: CLLocationCoordinate2D, name: String) {

        // Minic current map.
        let span = theMap.region.span
        let center = theMap.region.center
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: center),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: span)
        ]

        // Set a placemark at the mapcode location.
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: options)
    }


    /**
     * Truncate latitude to [-90, 90].
     */
    func truncLatitude(_ latitude: Double) -> CLLocationDegrees {
        return max(-90.0, min(90.0, latitude))
    }


    /**
     * Truncate latitude to [-180, 180].
     */
    func truncLongitude(_ latitude: Double) -> CLLocationDegrees {
        return max(-180.0, min(180.0 - 1.0e-12, latitude))
    }


    /**
     * Method to show an alert.
     */
    func showAlert(_ title: String, message: String, button: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: button, style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }


    /**
     * This method sets the center of the map and makes sure the zoom-level is limited if necessary.
     */
    func setMapCenterAndLimitZoom(_ center: CLLocationCoordinate2D, maxSpan: Double, animated: Bool) {
        if (theMap.region.span.latitudeDelta >= maxSpan) || (theMap.region.span.longitudeDelta >= maxSpan) {
            let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                               span: MKCoordinateSpanMake(maxSpan, maxSpan))
            theMap.setRegion(newRegion, animated: animated)
        } else {
            theMap.setCenter(mapcodeLocation, animated: animated)
        }
    }


    /**
     * This method checks if a coordinate is valid or not.
     */
    func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {

        // Skip things very close (0, 0). Unfortunately you get (0, 0) sometimes as a coordinate.
        return (abs(coordinate.latitude) > 0.1) || (abs(coordinate.latitude) > 0.1)
    }


    /**
     * Method to capture a UIView to UIImage.
     * Source: http://stackoverflow.com/questions/4334233/how-to-capture-uiview-to-uiimage-without-loss-of-quality-on-retina-display
     */
    func captureMapView(_ view: MKMapView, title: String) -> UIImage {

        // Create pin on map.
        let pin = MKPointAnnotation()
        pin.coordinate = view.centerCoordinate
        pin.title = title
        view.addAnnotation(pin)

        // Reset center of map to update pins.
        view.selectAnnotation(pin, animated: false)
        view.setCenter(view.centerCoordinate, animated: false)

        // Use temporary graphics context.
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0.0)
        let context = UIGraphicsGetCurrentContext()!
        context.interpolationQuality = CGInterpolationQuality.high
        view.drawHierarchy(in: view.frame, afterScreenUpdates: true)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Remove pin again.
        view.removeAnnotation(pin)
        return img!
    }


    /**
     * Switch to using the online API or the onboard client library.
     */
    func switchToOnlineAPI(online: Bool) {
        sendUserFeedback = UserDefaults.standard.bool(forKey: keySendUserFeedback)
        if online && sendUserFeedback {
            if !useOnlineAPI {
                debug(DEBUG, msg: "switchToOnlineAPI: Enable online API...")
            }
            theOnlineAPIIndicator.text = textIndicatorOnlineAPI
            useOnlineAPI = true
        } else {
            if useOnlineAPI {
                debug(DEBUG, msg: "switchToOnlineAPI: Enable onboard C library...")
            }
            theOnlineAPIIndicator.text = textIndicatorOfflineLibrary
            useOnlineAPI = false
        }
    }


    /**
     * This method trims all spaces around a string and removes double spacing.
     */
    func trimAllSpace(_ input: String) -> String {
        var output = input.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var changed = false
        repeat {
            let replaced = output.replacingOccurrences(of: "  ", with: " ")
            changed = (replaced != output)
            output = replaced
        } while changed
        return output
    }


    /**
     * Returns true if new coordinate is nil or no different from previous one.
     */
    func isEqualOrNil(_ newCoordinate: CLLocationCoordinate2D!, prevCoordinate: CLLocationCoordinate2D!) -> Bool {
        if newCoordinate == nil {
            // Nothing to do; new coordinate is nil.
        } else if prevCoordinate == nil {
            // New coordinate is not nil, old is nil, so not equal.
            return false
        } else {
            // Both are not nil. Check if they are equal.
            if !isAlmostEqual(prevCoordinate.latitude, degree2: newCoordinate.latitude) ||
                       !isAlmostEqual(prevCoordinate.longitude, degree2: newCoordinate.longitude) {
                return false
            }

            // Coordinates both exists and are equal.
        }
        return true
    }


    /**
     * Compares 2 degrees to microdegree level.
     */
    func isAlmostEqual(_ degree1: CLLocationDegrees, degree2: CLLocationDegrees) -> Bool {
        return abs(degree1 - degree2) < 1.0e-6
    }


    /**
     * Return meters per degree longitude (at a specific latitude).
     */
    func metersPerDegreeLonAtLan(_ atLatitude: Double) -> Double {
        let meters = metersPerDegreeLonAtEquator *
                cos(max(-85.0, min(85.0, abs(atLatitude))) / 180.0 * 3.141592654)
        return meters
    }


    /**
     * Simple debug loggin.
     */
    func debug(_ level: UInt8, msg: String) {
        var pre: String!
        if (level & debugMask) == TRACE {
            pre = "TRACE"
        } else if (level & debugMask) == DEBUG {
            pre = "DEBUG"
        } else if (level & debugMask) == INFO {
            pre = "INFO"
        } else if (level & debugMask) == WARN {
            pre = "WARN"
        } else if (level & debugMask) == ERROR {
            pre = "ERROR"
        } else {
            pre = nil
        }
        if pre != nil {
            print("\(pre!): \(msg)")
        }
    }


    /**
     * This method gets called when on low memory.
     */
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        debug(WARN, msg: "didReceiveMemoryWarning: Low memory warning")
    }
}
