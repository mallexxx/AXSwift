import Cocoa
import AXSwift

class AppDelegate: NSObject, NSApplicationDelegate {

  var observer: AXUIObserver?

  func applicationDidFinishLaunching(aNotification: NSNotification) {
    let app = AXApplication.all(for: "com.apple.finder").first!

    do {
      try startWatcher(app: app)
    } catch let error {
      NSLog("Error: Could not watch app [\(app)]: \(error)")
      abort()
    }
  }

  func startWatcher(app: AXApplication) throws {
    var updated = false
    observer = app.createObserver() { (observer: AXUIObserver, element: UIElement, event: AXNotification, info: [String: AnyObject]?) in
      var elementDesc: String!
      if let role = try? element.role()!, role == .window {
        elementDesc = "\(element) \"\(try! (element.get(attribute: .title) as? String)!)\""
      } else {
        elementDesc = "\(element)"
      }
      print("\(event) on \(elementDesc); info: \(info)")

      // Watch events on new windows
      if event == .windowCreated {
        do {
          try observer.add(notification: .uiElementDestroyed, for: element)
          try observer.add(notification: .moved, for: element)
        } catch let error {
          NSLog("Error: Could not watch [\(element)]: \(error)")
        }
      }

      // Group simultaneous events together with --- lines
      if !updated {
        updated = true
        // Set this code to run after the current run loop, which is dispatching all notifications.
        DispatchQueue.main.async {
          print("---")
          updated = false
        }
      }
    }

    try observer!.add(notification: .windowCreated, for: app)
    try observer!.add(notification: .mainWindowChanged, for: app)
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
  }

}
