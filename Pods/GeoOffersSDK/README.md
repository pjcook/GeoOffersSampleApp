# GeoOffersSDK

## GeoOffers: rewards platform for smarter cities
https://zappitrewards.com

## What is it?
The GeoOffersSDK lets you turn your mobile app into a powerful marketing tool. Effortlessly add geolocation driven proximity experiences to your app, engage your users and understand them with analytics. The SDK lets you quickly connect to the GeoOffers platform where you can configure your campaigns and marketing setup.

## How to use it

It is recommended to install the GeoOffersSDK using CocoaPods. The SDK supports a minimum iOS version of 11.4.

### CocoaPods
1. if you haven't already, install CocoaPods by executing the following:
```
$ sudo gem install cocoapods
```
> If you encounter any issues installing cocoapods, please refer to their [getting started guide](https://guides.cocoapods.org/using/getting-started.html)
2. add the following to your Podfile:
```
pod 'GeoOffersSDK'
```
3. install your pod updates with:
```
pod install
```
4. open the project workspace, not the project file and ensure the dependencies loaded properly.

## Configuration
This section describes how to configure the iOS SDK for use in your app.

### App info.plist
Make sure that the following entries are in your info.plist

| Key | Type | Detail |
| :--- | :--- | :--- |
| NSLocationAlwaysUsageDescription   | String  | We will use your location to provide relevant location based offers for you.|
| NSLocationAlwaysAndWhenInUseUsageDescription   | String  | We will use your location to provide relevant location based offers for you.|
| NSLocationWhenInUseUsageDescription   | String  | We will use your location to provide relevant location based offers for you.|

> **Important**
> If these keys are not present in your **_info.plist_** iOS location services won't start, preventing the app from GeoFencing and receiving location updates.

### App Capabilities
The GeoOffersSDK requires the app to enable selected _Capabilities_. Open the project in XCode, go to the Target, and select the _Capabilities_ configuration page.

Within the _Background Modes_ section, ensure the following entitlements are enabled:
• Background Fetch
• Remote Notifications
• Location updates

![background modes](Capabilities-Background-Modes.png "Background Modes")

You should also enable _Push Notifications_ and provide the platform with a _Push Notification AppKey_ or _Push Notification Certificates_

![push notificaions](Capabilities-Push-Notifications.png "Push Notifications")

### SDK Configuration

You should receive a **_registrationCode_** and **_authenticationToken_** from the platform team, you will need to configure the SDK with these values in order for it to successfully communicate with the platform.

#### GeoOffersConfiguration

You will need to create a _GeoOffersConfiguration_ object to pass to the _GeoOffersSDKService_ class.  Here is a definition of the configuration properties:

| Key | Type | Description | DefaultValue |
| :--- | :--- | :--- | :--- |
| registrationCode | String | Provide the value from the platform team | |
| authToken | String | Provide the value from the platform team | |
| testing | Bool | Points the SDK to Production or Staging | false |
| selectedCategoryTabBackgroundColor | String | The highlight colour for the buttons in the offers list view header | #FF0000 |
| minimumRefreshWaitTime | Double | Ideally we do not want to waste the users bandwidth so configure a sensible refresh period in **seconds** | 10 minutes |
| minimumDistance | Double | The minimum distance that a user should move before the SDK checks for offer updates **in meters** | 500 meters |
| mainAppUsesFirebase | Bool | The SDK uses Firebase for some of it's messaging functionality. If your app uses Firebase then set this flag to stop conflicts. The app will fail at launch if you use Firebase and don't set this option. | false |

#### GeoOffersSDKService

You should only create a single instance of this class and share it throughout your app. We strongly suggest creating a Singleton wrapper class where you can initialise this with the above _GeoOffersConfiguration_ once. See the _SampleApp_ for an example idea.

```
class GeoOffersWrapper {
   static let shared = GeoOffersWrapper()
   
   var geoOffers: GeoOffersSDKService = {
      let registrationCode = <registrationCode>
      let authToken = <authenticationToken>
      let configuration = GeoOffersConfigurationDefault(registrationCode: registrationCode, authToken: authToken, testing: true)
      let geoOffers = GeoOffersSDKServiceDefault(configuration: configuration)
      return geoOffers
   }()
}
```

### Integration

#### AppDelegate

The SDK requires the main app to forward certain **_AppDelegate_** method calls to the SDK to allow it to function correctly. Please implement the following functionality inside your **_AppDelegate_**.

##### didFinishLaunchingWithOptions

Initialise the GeoOffersSDK, we suggest using a singleton for simplification, but use your own preferred dependency injection pattern

Call the matching method on the GeoOffersSDK instance

```
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        GeoOffersWrapper.shared.geoOffers.application(application, didFinishLaunchingWithOptions: launchOptions)

        return true
    }
```

##### applicationDidBecomeActive

Call the matching method on the GeoOffersSDK instance

```
    func applicationDidBecomeActive(_ application: UIApplication) {
        GeoOffersWrapper.shared.geoOffers.applicationDidBecomeActive(application)
    }
```

##### performFetchWithCompletionHandler

If you want to handle the "completionHandler" then pass nil to the geoOffers function completionHandler

```
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        GeoOffersWrapper.shared.geoOffers.application(application, performFetchWithCompletionHandler: completionHandler)
    }
```

##### handleEventsForBackgroundURLSession

Call the matching method on the GeoOffersSDK instance

```
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        GeoOffersWrapper.shared.geoOffers.application(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
    }
```

##### didRegisterForRemoteNotificationsWithDeviceToken

Call the matching method on the GeoOffersSDK instance

```
    // Required if implementing Remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        GeoOffersWrapper.shared.geoOffers.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
```

##### didReceiveRemoteNotification

Call the matching methods on the GeoOffersSDK instance

```
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        GeoOffersWrapper.shared.geoOffers.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: nil)
    }
```

##### didReceiveRemoteNotification:completionHandler:

If you want to handle the "completionHandler" then pass nil to the geoOffers function completionHandler

Call the matching method on the GeoOffersSDK instance

```
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        GeoOffersWrapper.shared.geoOffers.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }
```

#### Offers List ViewController

The SDK will provide you with a UIViewController that will render the list of current offers to the user. You should call the following to get the UIViewController. Please put this into a UINavigationController and present it within your own app. We have done this so that you can push or present it from an existing view controller, or place it inside it's own tab depending on the style of your app.

```
GeoOffersWrapper.shared.geoOffers.buildOfferListViewController()
```

#### Permissions

The SDK will not function correctly until the app has the required permissions. We require **_Location_** and **_Push Notification_** permissions. We have added methods to the SDK that you can call to simplify calling the required code. You should choose when and where in your app to call these methods to increase the chance that the user will accept the permissions.

```
GeoOffersWrapper.shared.geoOffers.requestPushNotificationPermissions()

GeoOffersWrapper.shared.geoOffers.requestLocationPermissions()
```

#### Deeplinking to Coupon / Offer Page from Notification

The SDK sends the user local notifications when offers become available and the app is running in the background. If you would like to deeplink the user and present their coupon or offer when the app is launched from the user interacting with one of these notifications then you should do the following.

In the **AppDelegate** in application didFinishLaunchingWithOptions you should register yourself as the delegate for UNUserNotifications

```
// Register as the UNUserNotificationCenterDelegate to support deeplinking to the coupon when the user taps the notification and the app is closed

UNUserNotificationCenter.current().delegate = self
```

Implement the following delegate methods:

```
// Required if you want to implement deeplinking to coupon when user taps notification when the app is closed
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let request = notification.request
        deeplinkToCoupon(request.identifier, userInfo: request.content.userInfo)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        deeplinkToCoupon(request.identifier, userInfo: request.content.userInfo)
    }
}
```

and use the following code as an example implementation to present the users coupon

```
extension AppDelegate {
    private func deeplinkToCoupon(_ identifier: String, userInfo: [AnyHashable:Any]) {
        guard GeoOffersWrapper.shared.service.isGeoOffersNotification(userInfo: userInfo) else { return }
        let viewController = GeoOffersWrapper.shared.service.buildOfferListViewController()
        viewController.navigationItem.leftBarButtonItem = buildCloseButton()
        let navigationController = UINavigationController(rootViewController: viewController)
        window?.rootViewController?.present(navigationController, animated: true, completion: {
            GeoOffersWrapper.shared.service.deeplinkToCoupon(viewController, notificationIdentifier: identifier, userInfo: userInfo)
        })
    }
    
    private func buildCloseButton() -> UIBarButtonItem {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "close"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(closeCouponModal), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        let item = UIBarButtonItem(customView: button)
        return item
    }
    
    @objc private func closeCouponModal() {
        window?.rootViewController?.dismiss(animated: true, completion: nil)
    }
}
```
