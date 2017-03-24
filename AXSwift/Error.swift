// For some reason values don't get described in this enum, so we have to do it manually.

public enum AXUIError: String, Error {
    case success
    case failure
    case illegalArgument
    case invalidUIElement
    case invalidUIElementObserver
    case cannotComplete
    case attributeUnsupported
    case actionUnsupported
    case notificationUnsupported
    case notImplemented
    case notificationAlreadyRegistered
    case notificationNotRegistered
    case apiDisabled
    case noValue
    case parameterizedAttributeUnsupported
    case notEnoughPrecision

    init(_ error: AXError) {
        #if swift(>=3)
            switch (error) {
            case .success:
                self = .success
            case .failure:
                self = .failure
            case .illegalArgument:
                self = .illegalArgument
            case .invalidUIElement:
                self = .invalidUIElement
            case .invalidUIElementObserver:
                self = .invalidUIElementObserver
            case .cannotComplete:
                self = .cannotComplete
            case .attributeUnsupported:
                self = .attributeUnsupported
            case .actionUnsupported:
                self = .actionUnsupported
            case .notificationUnsupported:
                self = .notificationUnsupported
            case .notImplemented:
                self = .notImplemented
            case .notificationAlreadyRegistered:
                self = .notificationAlreadyRegistered
            case .notificationNotRegistered:
                self = .notificationNotRegistered
            case .apiDisabled:
                self = .apiDisabled
            case .noValue:
                self = .noValue
            case .parameterizedAttributeUnsupported:
                self = .parameterizedAttributeUnsupported
            case .notEnoughPrecision:
                self = .notEnoughPrecision
            }
        #else
            switch (error) {
            case .Success:
                self = .success
            case .Failure:
                self = .failure
            case .IllegalArgument:
                self = .illegalArgument
            case .InvalidUIElement:
                self = .invalidUIElement
            case .InvalidUIElementObserver:
                self = .invalidUIElementObserver
            case .CannotComplete:
                self = .cannotComplete
            case .AttributeUnsupported:
                self = .attributeUnsupported
            case .ActionUnsupported:
                self = .actionUnsupported
            case .NotificationUnsupported:
                self = .notificationUnsupported
            case .NotImplemented:
                self = .notImplemented
            case .NotificationAlreadyRegistered:
                self = .notificationAlreadyRegistered
            case .NotificationNotRegistered:
                self = .notificationNotRegistered
            case .APIDisabled:
                self = .apiDisabled
            case .NoValue:
                self = .noValue
            case .ParameterizedAttributeUnsupported:
                self = .parameterizedAttributeUnsupported
            case .NotEnoughPrecision:
                self = .notEnoughPrecision
            }
        #endif
    }
    
    private var valueAsString: String {
        return self.rawValue
    }
    
    public var description: String {
        return "AXError.\(valueAsString)"
    }
    
}
