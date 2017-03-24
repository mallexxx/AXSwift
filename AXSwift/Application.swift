#if swift(>=3)
#else
    public extension NSApplicationActivationPolicy {
        @nonobjc static let prohibited = NSApplicationActivationPolicy.Prohibited
        @nonobjc static let accessory = NSApplicationActivationPolicy.Accessory
        @nonobjc static let regular = NSApplicationActivationPolicy.Regular
    }
#endif
/// A `UIElement` for an application.
public final class AXApplication: UIElement {
  
  convenience init?(_ processID: pid_t) {
    guard processID > 0,
        let app = NSRunningApplication(processIdentifier: processID)
        else { return nil }
    
    self.init(app)
  }

    
  public convenience init?(_ app: NSRunningApplication) {
    guard !app.isTerminated else { return nil }
    #if swift(>=3)
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    #else
    let appElement = AXUIElementCreateApplication(app.processIdentifier).takeRetainedValue()
    #endif
    self.init(appElement)
  }

  /// Creates an `Application` for every running application with a UI.
  /// - returns: An array of `Application`s.
  public class func all() -> [AXApplication] {
    let runningApps = NSWorkspace.shared().runningApplications
    return runningApps
      .filter({ $0.activationPolicy != .prohibited })
      .flatMap({ AXApplication($0) })
  }

  /// Creates an `Application` for every running instance of the given `bundleID`.
  /// - returns: A (potentially empty) array of `Application`s.
  public class func all(for bundleID: String) -> [AXApplication] {
    let runningApps = NSWorkspace.shared().runningApplications
    return runningApps
      .filter({ $0.bundleIdentifier == bundleID })
      .flatMap({ AXApplication($0) })
  }

  /// Creates an `Observer` on this application, if it is still alive.
  public func createObserver(callback: @escaping  AXUIObserver.Callback) -> AXUIObserver? {
    do {
      return try AXUIObserver(processID: try pid(), callback: callback)
    } catch (let error) {
        if let error = error as? AXError, AXUIError(error) == .invalidUIElement {
          return nil
        } else {
            fatalError("Caught unexpected error creating observer: \(error)")
        }
    }
  }

  /// Creates an `Observer` on this application, if it is still alive.
  public func createObserver(callback: @escaping AXUIObserver.CallbackWithInfo) -> AXUIObserver? {
    do {
      return try AXUIObserver(processID: try pid(), callback: callback)
    } catch (let error) {
        if let error = error as? AXError, AXUIError(error) == .invalidUIElement {
            return nil
        } else {
            fatalError("Caught unexpected error creating observer: \(error)")
        }
    }
  }

  /// Returns a list of the application's visible windows.
  /// - returns: An array of `UIElement`s, one for every visible window. Or `nil` if the list cannot
  ///            be retrieved.
  public func windows() throws -> [UIElement]? {
    return try self.get(attribute: "AXWindows") as? [UIElement]
  }

  /// Returns the element at the specified top-down coordinates, or nil if there is none.
  public override func element(at point: CGPoint) throws -> UIElement? {
    return try super.element(at: point)
  }
}
