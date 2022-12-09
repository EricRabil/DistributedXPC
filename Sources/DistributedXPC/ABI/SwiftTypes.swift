//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation

public protocol ABI {
    static func serializeType<P>(_ type: P.Type) -> String
    static func deserializeType(_ type: String) -> Any.Type?
}

public struct SwiftABI: ABI {
    public static func serializeType<P>(_ type: P.Type) -> String {
        _mangledTypeName(type) ?? _typeName(type)
    }
    
    public static func deserializeType(_ type: String) -> Any.Type? {
        _typeByName(type)
    }
}
