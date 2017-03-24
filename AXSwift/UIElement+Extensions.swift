//
//  UIElement+Extensions.swift
//  SimplePlugin
//
//  Created by ALEKSEY MARTEMYANOV on 02.07.16.
//  Copyright © 2016 Sympli. All rights reserved.
//

import Foundation

extension UIElement {
    
    public func children(withRole role: AXRole? = nil) throws -> [UIElement]? {
        let array = try get(attribute: .children) as? [UIElement]
        
        guard let role = role else { return array }
        
        return array?.filter{
            if let elementRole = try? $0.role() {
                return elementRole == role
            } else {
                return false
            }
        }
    }
    
    public func find(rolesPath path: [AXRole]) throws -> [UIElement]? {
        var stack: [(root: UIElement, path: [AXRole])] = [(self, path)]
        var results: [UIElement]?
        while let step = stack.popLast() {
            var path = step.path
            let pathComponent = path.removeFirst()
            guard let children = try step.root.children(withRole: pathComponent) else { continue }
            
            if path.isEmpty {
                _=results?.append(contentsOf: children) ?? { results = children }()
            } else {
                stack.append(contentsOf: children.map{ ($0, path) })
            }
        }
        
        return results
    }
    
    public func toolbar() throws -> UIElement? {
        if let toolbar = try self.children(withRole: .toolbar)?.first {
            return toolbar
        } else if let toolbar = try self.children(withRole: .group)?
            .map({ try $0.children(withRole: .toolbar)}).reduce([], { $0 + ($1 ?? []) }).first {
            
            return toolbar
        }
        return nil
    }
    
    public func application() -> AXApplication? {
        do {
            let pid = try self.pid()
            return AXApplication(pid)
        } catch (_) {
            return nil
        }
    }
    
    public func runningApplication() -> NSRunningApplication? {
        do {
            let pid = try self.pid()
            return NSRunningApplication.init(processIdentifier: pid)
        } catch (_) {
            return nil
        }
    }
    
    public func isFocused() -> Bool? {
        do {
            let pid = try self.pid()
            let app = AXApplication(pid)
            let focusedWindow = try app?.get(attribute: .focusedWindow) as? UIElement
            return self == focusedWindow
        } catch (_) {
            return nil
        }
    }
}
