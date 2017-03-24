
/// A `UIElement` for the system-wide accessibility element, which can be used to retrieve global,
/// application-inspecific parameters like the currently focused element.
public class SystemWideElement: UIElement {
  public static var shared = SystemWideElement()
    
  private convenience init() {
    #if swift(>=3)
        let element = AXUIElementCreateSystemWide()
    #else
        let element = AXUIElementCreateSystemWide().takeRetainedValue()
    #endif
    self.init(element)
  }

  /// Returns the element at the specified top-down coordinates, or nil if there is none.
  public override func element(at point: CGPoint) throws -> UIElement? {
    return try super.element(at: point)
  }
}
