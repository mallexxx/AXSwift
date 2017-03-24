import Cocoa
import AXSwift

class ApplicationDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    // Check that we have permission
    guard UIElement.isProcessTrusted(withPrompt: true) else {
      NSLog("No accessibility API permission, exiting")
      NSRunningApplication.current().terminate()
      return
    }

    // Get Active Application
    if let application = NSWorkspace.shared().frontmostApplication {
      NSLog("localizedName: \(application.localizedName), processIdentifier: \(application.processIdentifier)")
      let uiApp = AXApplication(application)!
      NSLog("windows: \(try! uiApp.windows())")
      NSLog("attributes: \(try! uiApp.attributes())")
        NSLog("at 0,0: \(try! uiApp.element(at: CGPoint(x: 0, y: 0)))")
      if let bundleIdentifier = application.bundleIdentifier {
        NSLog("bundleIdentifier: \(bundleIdentifier)")
        let windows = try! AXApplication.all(for: bundleIdentifier).first!.windows()
        NSLog("windows: \(windows)")
      }
    }

    // Get Application by bundleIdentifier
    let app = AXApplication.all(for: "com.apple.finder").first!
    NSLog("finder: \(app)")
    NSLog("role: \(try! app.role()!)")
    NSLog("windows: \(try! app.windows()!)")
    NSLog("attributes: \(try! app.attributes())")
    if let title = try! app.get(attribute: .title) as? String {
      NSLog("title: \(title)")
    }
    NSLog("multi: \(try! app.get(attributes: ["AXRole", "asdf", "AXTitle"]))")
    NSLog("multi: \(try! app.get(attributes: [.role, .title]))")

    // Try to set an unsettable attribute
    if let window = try! app.windows()?.first {
      do {
        try window.set(value: "my title", for: .title)
        let newTitle = try! window.get(attribute: .title) as! String
        NSLog("title set; result = \(newTitle)")
      } catch {
        NSLog("error caught trying to set title of window: \(error)")
      }
    }

    NSLog("system wide:")
    NSLog("role: \(try! SystemWideElement.shared.role()!)")
    // NSLog("windows: \(try! sys.windows())")
    NSLog("attributes: \(try! SystemWideElement.shared.attributes())")

    NSRunningApplication.current().terminate()
  }
}
