/// Observers watch for events on an application's UI elements.
///
/// Events are received as part of the application's default run loop.
///
/// - seeAlso: `UIElement` for a list of exceptions that can be thrown.
public final class AXUIObserver {
  public typealias Callback =
    (_ observer: AXUIObserver, _ element: UIElement, _ notification: AXNotification) -> Void
  public typealias CallbackWithInfo =
    (_ observer: AXUIObserver, _ element: UIElement, _ notification: AXNotification, _ info: [String: AnyObject]?) -> Void

  let pid: pid_t
  let axObserver: AXObserver!
  let callback: Callback?
  let callbackWithInfo: CallbackWithInfo?

    public func application() throws -> AXApplication {
        if let app = AXApplication(self.pid) {
            return app
        } else {
            throw AXUIError.failure
        }
    }

  /// Creates and starts an observer on the given `processID`.
  public init(processID: pid_t, callback: @escaping Callback) throws {
    var axObserver: AXObserver?
    let error = AXUIError(AXObserverCreate(processID, internalCallback, &axObserver))

    self.pid              = processID
    self.axObserver       = axObserver
    self.callback         = callback
    self.callbackWithInfo = nil

    guard error == .success else {
      throw error
    }
    assert(axObserver != nil)

    start()
  }

  /// Creates and starts an observer on the given `processID`.
  ///
  /// Use this initializer if you want the extra user info provided with notifications.
  /// - seeAlso: [UserInfo Keys for Posting Accessibility Notifications](https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSAccessibility_Protocol_Reference/index.html#//apple_ref/doc/constant_group/UserInfo_Keys_for_Posting_Accessibility_Notifications)
  public init(processID: pid_t, callback: @escaping CallbackWithInfo) throws {
    var axObserver: AXObserver?
    let error = AXUIError(AXObserverCreateWithInfoCallback(processID, internalCallback, &axObserver))

    self.pid              = processID
    self.axObserver       = axObserver
    self.callback         = nil
    self.callbackWithInfo = callback

    guard error == .success else {
      throw error
    }
    assert(axObserver != nil)

    start()
  }

  /// Starts watching for events. You don't need to call this method unless you use `stop()`.
  ///
  /// If the observer has already been started, this method does nothing.
  public func start() {
    #if swift(>=3)
    CFRunLoopAddSource(
        RunLoop.current.getCFRunLoop(),
          AXObserverGetRunLoopSource(axObserver),
          CFRunLoopMode.defaultMode)
    #else
        CFRunLoopAddSource(
            NSRunLoop.currentRunLoop().getCFRunLoop(),
            AXObserverGetRunLoopSource(axObserver).takeUnretainedValue(),
            kCFRunLoopDefaultMode)
    #endif
  }

  /// Stops sending events to your callback until the next call to `start`.
  ///
  /// If the observer has already been started, this method does nothing.
  ///
  /// - important: Events will still be queued in the target process until the Observer is started
  ///              again or destroyed. If you don't want them, create a new Observer.
  public func stop() {
    #if swift(>=3)
    CFRunLoopRemoveSource(
        RunLoop.current.getCFRunLoop(),
          AXObserverGetRunLoopSource(axObserver),
          CFRunLoopMode.defaultMode)
    #else
        CFRunLoopRemoveSource(
            NSRunLoop.currentRunLoop().getCFRunLoop(),
            AXObserverGetRunLoopSource(axObserver).takeUnretainedValue(),
            kCFRunLoopDefaultMode)
    #endif
  }

  /// Adds a notification for the observer to watch.
  ///
  /// - parameter notification: The name of the notification to watch for.
  /// - parameter forElement: The element to watch for the notification on. Must belong to the
  ///                         application this observer was created on.
  /// - seeAlso: [Notificatons](https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSAccessibility_Protocol_Reference/index.html#//apple_ref/c/data/NSAccessibilityAnnouncementRequestedNotification)
  /// - note: The underlying API returns an error if the notification is already added, but that
  ///         error is not passed on for consistency with `start()` and `stop()`.
  /// - throws: `Error.NotificationUnsupported`: The element does not support notifications (note
  ///           that the system-wide element does not support notifications).
  public func add(notification axnotification: AXNotification, for element: UIElement) throws {
    #if swift(>=3)
    let selfPtr = unsafeBitCast(Unmanaged.passUnretained(self), to: UnsafeMutableRawPointer.self)
    let error = AXUIError(AXObserverAddNotification(axObserver, element.element, axnotification.rawValue as CFString, selfPtr))
    guard error == .success || error == .notificationAlreadyRegistered else {
      throw error
    }
    #else
    let selfPtr = UnsafeMutablePointer<AXUIObserver>(Unmanaged.passUnretained(self).toOpaque())
    let error = AXUIError(AXObserverAddNotification(axObserver, element.element, axnotification.rawValue, selfPtr))
    guard error == .success || error == .notificationAlreadyRegistered else {
        throw error
    }
    #endif
  }

  /// Removes a notification from the observer.
  ///
  /// - parameter notification: The name of the notification to stop watching.
  /// - parameter forElement: The element to stop watching the notification on.
  /// - note: The underlying API returns an error if the notification is not present, but that
  ///         error is not passed on for consistency with `start()` and `stop()`.
  /// - throws: `Error.NotificationUnsupported`: The element does not support notifications (note
  ///           that the system-wide element does not support notifications).
  public func remove(notification: AXNotification, for element: UIElement) throws {
    let error = AXUIError(AXObserverRemoveNotification(axObserver, element.element, notification.rawValue as CFString))
    guard error == .success || error == .notificationNotRegistered else {
      throw error
    }
  }
}

private func internalCallback(axObserver: AXObserver,
                              axElement: AXUIElement,
                              notification: CFString,
                              userData: UnsafeMutableRawPointer?) {
    #if swift(>=3)
    guard let userData = userData else { return }
    #endif
    let observer = Unmanaged<AXUIObserver>.fromOpaque(UnsafeRawPointer(userData)).takeUnretainedValue()
    let element  = UIElement(axElement)
    let notif    = AXNotification(rawValue: notification as String)!
    observer.callback!(observer, element, notif)
}

private func internalCallback(axObserver: AXObserver,
                                      axElement: AXUIElement,
                                      notification: CFString,
                                      cfInfo: CFDictionary,
                                      userData: UnsafeMutableRawPointer?) {
    #if swift(>=3)
    guard let userData = userData else { return }
    #endif
    let observer = Unmanaged<AXUIObserver>.fromOpaque(UnsafeRawPointer(userData)).takeUnretainedValue()
    let element  = UIElement(axElement)
    let info     = cfInfo as NSDictionary? as! [String: AnyObject]?
    let notif    = AXNotification(rawValue: notification as String)!
    observer.callbackWithInfo!(observer, element, notif, info)
}
