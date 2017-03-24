/// Holds and interacts with any accessibility element.
///
/// This class wraps every operation that operates on AXUIElements.
///
/// - seeAlso: [OS X Accessibility Model](https://developer.apple.com/library/mac/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXmodel.html)
///
/// Note that every operation involves IPC and is tied to the event loop of the target process. This
/// means that operations are synchronous and can hang until they time out. The default timeout is
/// 6 seconds, but it can be changed using `setMessagingTimeout` and `setGlobalMessagingTimeout`.
///
/// Every attribute- or action-related function has an enum version and a String version. This is
/// because certain processes might report attributes or actions not documented in the standard API.
/// These will be ignored by enum functions (and you can't specify them). Most users will want to
/// use the enum-based versions, but if you want to be exhaustive or use non-standard attributes and
/// actions, you can use the String versions.
///
/// ### Error handling
///
/// Unless otherwise specified, during reads, "missing data/attribute" errors are handled by
/// returning optionals as nil. During writes, missing attribute errors are thrown.
///
/// Other failures are all thrown, including if messaging fails or the underlying AXUIElement
/// becomes invalid.
///
/// #### Possible Errors
/// - `Error.APIDisabled`: The accessibility API is disabled. Your application must request and
///                        receive special permission from the user to be able to use these APIs.
/// - `Error.InvalidUIElement`: The UI element has become invalid, perhaps because it was destroyed.
/// - `Error.CannotComplete`: There is a problem with messaging, perhaps because the application is
///                           being unresponsive. This error will be thrown when a message times out.
/// - `Error.NotImplemented`: The process does not fully support the accessibility API.
/// - Anything included in the docs of the method you are calling.
///
/// Any undocumented errors thrown are bugs and should be reported.
///
/// - seeAlso: [AXUIElement.h reference](https://developer.apple.com/library/mac/documentation/ApplicationServices/Reference/AXUIElement_header_reference/)
#if swift(>=3)
extension AXValue {
    func takeRetainedValue() -> AXValue {
        return self
    }
}
#else
    extension AXValueType {
        @nonobjc static let cgRect = AXValueType.CGRect
        @nonobjc static let cfRange = AXValueType.CFRange
        @nonobjc static let cgSize = AXValueType.CGSize
        @nonobjc static let cgPoint = AXValueType.CGPoint
        @nonobjc static let illegal = AXValueType.Illegal
        @nonobjc static let axError = AXValueType.AXError
    }
#endif
public class UIElement {
  public let element: AXUIElement

  /// Create a UIElement from a raw AXUIElement object.
  ///
  /// The state and role of the AXUIElement is not checked.
  public required init(_ nativeElement: AXUIElement) {
    // Since we are dealing with low-level C APIs, it never hurts to double check types.
    assert(CFGetTypeID(nativeElement) == AXUIElementGetTypeID(), "nativeElement is not an AXUIElement")

    element = nativeElement
  }

  /// Checks if the current process is a trusted accessibility client. If false, all APIs will throw
  /// errors.
  ///
  /// - parameter withPrompt: Whether to show the user a prompt if the process is untrusted. This
  ///                         happens asynchronously and does not affect the return value.
  public class func isProcessTrusted(withPrompt showPrompt: Bool = false) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: showPrompt as CFBoolean]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
  }

  /// Timeout in seconds for all UIElement messages. Use this to control how long a method call can
  /// delay execution. The default is `0` which means to use the system default.
//  public class var globalMessagingTimeout: Float {
//    get { return systemWideElement.messagingTimeout }
//    set { systemWideElement.messagingTimeout = newValue }
//  }

  // MARK: - Attributes

  /// Returns the list of all attributes.
  ///
  /// Does not include parameterized attributes.
  public func attributes() throws -> [AXAttribute] {
    let attrs = try attributesAsStrings()
    for attr in attrs where AXAttribute(rawValue: attr) == nil { NSLog("Unrecognized attribute: \(attr)") }
    return attrs.flatMap({ AXAttribute(rawValue: $0) })
  }

  // This version is named differently so the caller doesn't have to specify the return type when
  // using the enum version.
  public func attributesAsStrings() throws -> [String] {
    var names: CFArray?
    let error = AXUIError(AXUIElementCopyAttributeNames(element, &names))

    if error == .noValue || error == .attributeUnsupported {
      return []
    }

    guard error == .success else {
      throw error
    }

    // We must first convert the CFArray to a native array, then downcast to an array of strings.
    return names! as [AnyObject] as! [String]
  }

  /// Returns whether `attribute` is supported by this element.
  ///
  /// The `attribute` method returns nil for unsupported attributes and empty attributes alike,
  /// which is more convenient than dealing with exceptions (which are used for more serious
  /// errors). However, if you'd like to specifically test an attribute is actually supported, you
  /// can use this method.
  public func supports(attribute attr: AXAttribute) throws -> Bool {
    return try supports(attribute: attr.rawValue)
  }

  public func supports(attribute attr: String) throws -> Bool {
    // Ask to copy 0 values, since we are only interested in the return code.
    var value: CFArray?
    let error = AXUIError(AXUIElementCopyAttributeValues(element, attr as CFString, 0, 0, &value))

    if error == .attributeUnsupported {
      return false
    }

    if error == .noValue {
      return true
    }

    guard error == .success else {
      throw error
    }

    return true
  }

  /// Returns whether `attribute` is writeable.
  public func isSettable(attribute attr: AXAttribute) throws -> Bool {
    return try isSettable(attribute: attr.rawValue)
  }

  public func isSettable(attribute attr: String) throws -> Bool {
    var settable: DarwinBoolean = false
    let error = AXUIError(AXUIElementIsAttributeSettable(element, attr as CFString, &settable))

    if error == .noValue || error == .attributeUnsupported {
      return false
    }

    guard error == .success else {
      throw error
    }

    return settable.boolValue
  }

  /// Returns the value of `attribute`, if it exists.
  ///
  /// - parameter attribute: The name of a (non-parameterized) attribute.
  ///
  /// - returns: An optional containing the value of `attribute` as the desired type, or nil.
  ///            If `attribute` is an array, all values are returned.
  ///
  /// - warning: This method force-casts the attribute to the desired type, which will abort if the
  ///            cast fails. If you want to check the return type, ask for Any.
  public func get(attribute attr: AXAttribute) throws -> Any? {
    return try self.get(attribute: attr.rawValue)
  }

  public func get(attribute attr: String) throws -> Any? {
    var value: AnyObject?
    
    AXUIElementSetMessagingTimeout(element, 1.5)
    defer {
        AXUIElementSetMessagingTimeout(element, 0)
    }
    
    let error = AXUIError(AXUIElementCopyAttributeValue(element, attr as CFString, &value))

    if error == .noValue || error == .attributeUnsupported {
      return nil
    }

    guard error == .success else {
      throw error
    }

    return unpack(axValue: value!)
  }

  /// Sets the value of `attribute` to `value`.
  ///
  /// - warning: Unlike read-only methods, this method throws if the attribute doesn't exist.
  ///
  /// - throws:
  ///   - `Error.AttributeUnsupported`: `attribute` isn't supported.
  ///   - `Error.IllegalArgument`: `value` is an illegal value.
  ///   - `Error.Failure`: A temporary failure occurred.
  public func set(value val: Any, for attribute: AXAttribute) throws {
    try self.set(value: val, for: attribute.rawValue)
  }

  public func set(value val: Any, for attribute: String) throws {
    let error = AXUIError(AXUIElementSetAttributeValue(element, attribute as CFString, pack(axValue: val) as CFTypeRef))

    guard error == .success else {
      throw error
    }
  }

  /// Gets multiple attributes of the element at once.
  ///
  /// - parameter attributes: An array of attribute names. Nonexistent attributes are ignored.
  ///
  /// - returns: A dictionary mapping provided parameter names to their values. Parameters which
  ///            don't exist or have no value will be absent.
  ///
  /// - throws: If there are any errors other than .NoValue or .AttributeUnsupported, it will throw
  ///           the first one it encounters.
  ///
  /// - note: Presumably you would use this API for performance, though it's not explicitly
  ///         documented by Apple that there is actually a difference.
  public func get(names attrnames: AXAttribute...) throws -> [AXAttribute: Any] {
    return try get(attributes: attrnames)
  }

  public func get(attributes attrs: [AXAttribute]) throws -> [AXAttribute: Any] {
    let values = try fetch(attributes: attrs.map({ $0.rawValue }))
    return try pack(attributes: attrs, values: values)
  }

  public func get(attributes attrs: [String]) throws -> [String: Any] {
    let values = try fetch(attributes: attrs)
    return try pack(attributes: attrs, values: values)
  }

  // Helper: Gets list of values
  private func fetch(attributes attrs: [String]) throws -> [AnyObject] {
    var valuesCF: CFArray?
    let error = AXUIError(AXUIElementCopyMultipleAttributeValues(
      element,
      attrs as CFArray,
      AXCopyMultipleAttributeOptions(rawValue: 0),  // keep going on errors (particularly NoValue)
      &valuesCF))

    guard error == .success else {
      throw error
    }

    return valuesCF! as [AnyObject]
  }

  // Helper: Packs names, values into dictionary
  private func pack<Attr>(attributes attrs: [Attr], values: [AnyObject]) throws -> [Attr: Any] {
    var result = [Attr: Any]()
    for (index, attribute) in attrs.enumerated() {
      if try checkMultiAttrValue(value: values[index]) {
        result[attribute] = unpack(axValue: values[index])
      }
    }
    return result
  }

  // Helper: Checks if value is present and not an error (throws on nontrivial errors).
  private func checkMultiAttrValue(value val: AnyObject) throws -> Bool {
    // Check for null
    if val is NSNull {
      return false
    }

    // Check for error
    if CFGetTypeID(val) == AXValueGetTypeID() &&
       AXValueGetType(val as! AXValue).rawValue == kAXValueAXErrorType {
      var axError: AXError?
      AXValueGetValue(val as! AXValue, AXValueType(rawValue: kAXValueAXErrorType)!, &axError)
      let error = axError != nil ? AXUIError(axError!) : .noValue
        
      if error == .noValue || error == .attributeUnsupported {
        return false
      } else {
        throw error
      }
    }

    return true
  }

  /// Returns a subset of values from an array attribute.
  ///
  /// - parameter attribute: The name of the array attribute.
  /// - parameter startAtIndex: The index of the array to start taking values from.
  /// - parameter maxValues: The maximum number of values you want.
  ///
  /// - returns: An array of up to `maxValues` values starting at `startAtIndex`.
  ///   - The array is empty if `startAtIndex` is out of range.
  ///   - `nil` if the attribute doesn't exist or has no value.
  ///
  /// - throws: `Error.IllegalArgument` if the attribute isn't an array.
  public func values<T: AnyObject>
      (for attribute: AXAttribute, startAtIndex index: Int, maxValues: Int) throws -> [T]? {
    return try values(for: attribute.rawValue, startAtIndex: index, maxValues: maxValues)
  }

  public func values<T: AnyObject>
      (for attribute: String, startAtIndex index: Int, maxValues: Int) throws -> [T]? {
    var values: CFArray?
    let error = AXUIError(AXUIElementCopyAttributeValues(element, attribute as CFString, index, maxValues, &values))

    if error == .noValue || error == .attributeUnsupported {
      return nil
    }

    guard error == .success else {
      throw error
    }

    let array = values! as [AnyObject]
    return array.map({ unpack(axValue: $0) as! T })
  }

  /// Returns the number of values an array attribute has.
  /// - returns: The number of values, or `nil` if `attribute` isn't an array (or doesn't exist).
  public func valueCount(for attribute: AXAttribute) throws -> Int? {
    return try valueCount(for: attribute.rawValue)
  }

  public func valueCount(for attribute: String) throws -> Int? {
    var count: Int = 0
    let error = AXUIError(AXUIElementGetAttributeValueCount(element, attribute as CFString, &count))

    if error == .attributeUnsupported || error == .illegalArgument {
      return nil
    }

    guard error == .success else {
      throw error
    }

    return count
  }

  // MARK: Parameterized attributes

  /// Returns a list of all parameterized attributes of the element.
  ///
  /// Parameterized attributes are attributes that require parameters to retrieve. For example,
  /// the cell contents of a spreadsheet might require the row and column of the cell you want.
  public func parameterizedAttributes() throws -> [AXAttribute] {
    return try parameterizedAttributesAsStrings().flatMap({ AXAttribute(rawValue: $0) })
  }

  public func parameterizedAttributesAsStrings() throws -> [String] {
    var names: CFArray?
    let error = AXUIError(AXUIElementCopyParameterizedAttributeNames(element, &names))

    if error == .noValue || error == .attributeUnsupported {
      return []
    }

    guard error == .success else {
      throw error
    }

    // We must first convert the CFArray to a native array, then downcast to an array of strings.
    return names! as [AnyObject] as! [String]
  }

  /// Returns the value of the parameterized attribute `attribute` with parameter `param`.
  ///
  /// The expected type of `param` depends on the attribute. See the
  /// [NSAccessibility Informal Protocol Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Protocols/NSAccessibility_Protocol/)
  /// for more info.
  public func parameterizedAttribute(_ attribute: AXAttribute, param: Any) throws -> Any? {
    return try parameterizedAttribute(attribute.rawValue, param: param)
  }

  public func parameterizedAttribute(_ attribute: String, param: Any) throws -> Any? {
    var value: AnyObject?
    let error = AXUIError(AXUIElementCopyParameterizedAttributeValue(element, attribute as CFString, pack(axValue: param) as CFTypeRef, &value))

    if error == .noValue || error == .attributeUnsupported {
      return nil
    }

    guard error == .success else {
      throw error
    }

    return unpack(axValue: value!)
  }

  // MARK: Attribute helpers

  // Checks if the value is an AXValue and if so, unwraps it.
  // If the value is an AXUIElement, wraps it in UIElement.
  private func unpack(axValue value: AnyObject) -> Any {
    switch CFGetTypeID(value) {
    case AXUIElementGetTypeID():
      return UIElement(value as! AXUIElement)
    case AXValueGetTypeID():
      let type = AXValueGetType(value as! AXValue)
      
      if type == .axError {
        var result: AXError!
        let success = AXValueGetValue(value as! AXValue, type, &result)
        assert(success)
        return AXUIError(result)
        
      } else if type == .cfRange {
        var result: CFRange = CFRange()
        let success = AXValueGetValue(value as! AXValue, type, &result)
        assert(success)
        return result
        
      } else if type == .cgPoint {
        var result: CGPoint = CGPoint.zero
        let success = AXValueGetValue(value as! AXValue, type, &result)
        assert(success)
        return result
        
      } else if type == .cgRect {
        var result: CGRect = CGRect.zero
        let success = AXValueGetValue(value as! AXValue, type, &result)
        assert(success)
        return result
        
      } else if type == .cgSize {
        var result: CGSize = CGSize.zero
        let success = AXValueGetValue(value as! AXValue, type, &result)
        assert(success)
        return result
      } else {
        return value
      }
    default:
      if let array = value as? [AXUIElement] {
        return array.map{ UIElement($0) }
      }
      return value
    }
  }

  // Checks if the value is one supported by AXValue and if so, wraps it.
  // If the value is a UIElement, unwraps it to an AXUIElement.
  private func pack(axValue value: Any) -> Any {
    switch value {
    case let val as UIElement:
      return val.element
    case let val as [UIElement]:
      return val.map{ $0.element }
    case var val as CFRange:
      return AXValueCreate(AXValueType(rawValue: kAXValueCFRangeType)!, &val)!.takeRetainedValue()
    case var val as CGPoint:
      return AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!.takeRetainedValue()
    case var val as CGRect:
      return AXValueCreate(AXValueType(rawValue: kAXValueCGRectType)!, &val)!.takeRetainedValue()
    case var val as CGSize:
      return AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!.takeRetainedValue()
    default:
      return value  // must be an object to pass to AX
    }
  }

  // MARK: - Actions

  /// Returns a list of actions that can be performed on the element.
  public func actions() throws -> [AXAction] {
    return try actionsAsStrings().flatMap({ AXAction(rawValue: $0) })
  }

  public func actionsAsStrings() throws -> [String] {
    var names: CFArray?
    let error = AXUIError(AXUIElementCopyActionNames(element, &names))

    if error == .noValue || error == .attributeUnsupported {
      return []
    }

    guard error == .success else {
      throw error
    }

    // We must first convert the CFArray to a native array, then downcast to an array of strings.
    return names! as [AnyObject] as! [String]
  }

  /// Returns the human-readable description of `action`.
  public func description(for action: AXAction) throws -> String? {
    return try description(for: action.rawValue)
  }

  public func description(for action: String) throws -> String? {
    var description: CFString?
    let error = AXUIError(AXUIElementCopyActionDescription(element, action as CFString, &description))

    if error == .noValue || error == .actionUnsupported {
      return nil
    }

    guard error == .success else {
      throw error
    }

    return description! as String
  }

  /// Performs the action `action` on the element, returning on success.
  ///
  /// - note: If the action times out, it might mean that the application is taking a long time to
  ///         actually perform the action. It doesn't necessarily mean that the action wasn't performed.
  /// - throws: `Error.ActionUnsupported` if the action is not supported.
  public func perform(_ action: AXAction) throws {
    try perform(action.rawValue)
  }

  public func perform(_ action: String) throws {
    let error = AXUIError(AXUIElementPerformAction(element, action as CFString))

    guard error == .success else {
      throw error
    }
  }

  // MARK: -

  /// Returns the process ID of the application that the element is a part of.
  ///
  /// Throws only if the element is invalid (`Errors.InvalidUIElement`).
  public func pid() throws -> pid_t {
    var pid: pid_t = -1
    let error = AXUIError(AXUIElementGetPid(element, &pid))

    guard error == .success else {
      throw error
    }

    return pid
  }

  /// The timeout in seconds for all messages sent to this element. Use this to control how long
  /// a method call can delay execution. The default is `0`, which means to use the global timeout.
  ///
  /// - note: Only applies to this instance of UIElement, not other instances that happen to equal it.
  /// - seeAlso: `UIElement.globalMessagingTimeout(_:)`
  public var messagingTimeout: Float = 0 {
    didSet {
      messagingTimeout = max(messagingTimeout, 0)
      let error = AXUIError(AXUIElementSetMessagingTimeout(element, messagingTimeout))

      // InvalidUIElement errors are only relevant when actually passing messages, so we can ignore
      // them here.
      guard error == .success || error == .invalidUIElement else {
        fatalError("Unexpected error setting messaging timeout: \(error)")
      }
    }
  }

  // Gets the element at the specified coordinates.
  // This can only be called on applications and the system-wide element, so it is internal here.
  func element(at point: CGPoint) throws -> UIElement? {
    var result: AXUIElement?
    let error = AXUIError(AXUIElementCopyElementAtPosition(element, Float(point.x), Float(point.y), &result))

    if error == .noValue {
      return nil
    }

    guard error == .success else {
      throw error
    }

    return UIElement(result!)
  }
}

// MARK: - CustomStringConvertible

extension UIElement: CustomStringConvertible {
  public var description: String {
    var roleString: String
    var description: String?
    let pid = try? self.pid()
    do {
      let role = try self.role()
      roleString = role?.rawValue ?? "UIElementNoRole"

      if role == .application {
        description = pid.flatMap{NSRunningApplication.init(processIdentifier: $0)}.flatMap{$0.bundleIdentifier} ?? ""
      } else if role == .window {
        description = (try? self.get(attribute: .title) as? String ?? "") ?? ""
      }
    } catch (let error) {
        if let error = error as? AXError , AXUIError(error) == .invalidUIElement {
          roleString = "InvalidUIElement"
        } else {
          roleString = "UnknownUIElement"
        }
    }

    let pidString = (pid == nil) ? "??" : String(pid!)
    return "<\(roleString) \"\(description ?? String(describing: element))\" (pid=\(pidString))>"
  }

  public var inspect: String {
    guard let attributeNames = try? attributes() else {
      return "InvalidUIElement"
    }
    guard let attributes = try? get(attributes: attributeNames) else {
      return "InvalidUIElement"
    }
    return "\(attributes)"
  }
}

// MARK: - Equatable

extension UIElement: Equatable { }
public func ==(lhs: UIElement, rhs: UIElement) -> Bool {
  return CFEqual(lhs.element, rhs.element)
}

// MARK: - Convenience getters

extension UIElement {
  /// Returns the role (type) of the element, if it reports one.
  ///
  /// Almost all elements report a role, but this could return nil for elements that aren't finished
  /// initializing.
  ///
  /// - seeAlso: [Roles](https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSAccessibility_Protocol_Reference/index.html#//apple_ref/doc/constant_group/Roles)
  public func role() throws -> AXRole? {
    // should this be non-optional?
    if let str = try self.get(attribute: .role) as? String {
      return AXRole(rawValue: str)
    } else {
      return nil
    }
  }

  /// - seeAlso: [Subroles](https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSAccessibility_Protocol_Reference/index.html#//apple_ref/doc/constant_group/Subroles)
  public func subrole() throws -> AXSubrole? {
    if let str = try self.get(attribute: .subrole) as? String {
      return AXSubrole(rawValue: str)
    } else {
      return nil
    }
  }
}
