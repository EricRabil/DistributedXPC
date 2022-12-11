//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/11/22.
//

import Foundation

fileprivate extension IDSMessageContext {
    static var properties: [String] = {
        var properties: [String] = []
        
        var count: UInt32 = 0
        if let list = class_copyPropertyList(IDSMessageContext.self, &count).map({ UnsafeMutableBufferPointer(start: $0, count: Int(count)) }) {
            defer { list.deallocate() }
            for property in list {
                properties.append(String(cString: property_getName(property)))
            }
        }
        
        return properties
    }()
}

public extension IDSMessageContext {
    var propertiesDescription: String {
        Self.properties.reduce(into: [String]()) { strings, property in
            guard let value = value(forKey: property) else {
                return
            }
            var description: String {
                if let object = value as? NSObject {
                    return object.debugDescription
                } else {
                    return String(describing: value)
                }
            }
            strings.append("\(property)=\(description)")
        }.joined(separator: " ")
    }
    
    var _debugDescription: String {
        """
        <IDSMessageContext \(propertiesDescription)/>
        """
    }
}
