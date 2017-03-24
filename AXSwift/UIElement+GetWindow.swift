//
//  UIElement+GetWindow.swift
//  SimplePlugin
//
//  Created by ALEKSEY MARTEMYANOV on 02.07.16.
//  Copyright © 2016 Sympli. All rights reserved.
//

import Foundation

extension UIElement {
    
    public func getWindowId() throws -> Int {
        var value: UInt32 = 0
        let error = _AXUIElementGetWindow(element, &value)
        
        guard error.rawValue == 0 else {
            throw AXUIError(error)
        }
        
        return Int(value)
    }
            
}
