import UIKit
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseAuth)
        
        #endif
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        #if canImport(FirebaseAuth)
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        #endif
        completionHandler(.newData)
    }

 
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        #if canImport(FirebaseAuth)
        if Auth.auth().canHandle(url) {
            return true
        }
        #endif
        return false
    }
}

///STAR WARS EPISODE 1: THE PHANTOM MENACE
///STAR WARS EPISODE 2: THE CLONE WARS
///STAR WARS EPISODE 3: THE REVENGE OF THE SITH
///STAR WARS EPISODE 4: A NEW HOPE
///STAR WARS EPISODE 5: THE EMPIRE STRIKES BACK
///STAR WARS EPISODE 6: THE RETURN OF THE JEDI
///STAR WARS EPISODE 7: THE FORCE AWAKENS
///STAR WARS EPISODE 8: THE LAST JEDI
///STAR WARS EPISODE 9: THE RISE OF SKYWALKER
///ROGUE ONE: A STAR WARS STORY
///SOLO: A STAR WARS STORY

