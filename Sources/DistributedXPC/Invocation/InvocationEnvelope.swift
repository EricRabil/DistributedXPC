//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import XPCCollections

public struct InvocationEnvelope {
    public var target: String?
    public var genericSubstitutions: XPCArray
    public var arguments: XPCArray
    public var returnType: String?
    public var errorType: String?
    
    public init(_ dictionary: XPCDictionary) {
        target = dictionary[safe: "target"]
        genericSubstitutions = dictionary[safe: "generics"] ?? XPCArray()
        arguments = dictionary[safe: "arguments"] ?? XPCArray()
        returnType = dictionary[safe: "returnType"]
        errorType = dictionary[safe: "errorType"]
    }
    
    public init() {
        genericSubstitutions = XPCArray()
        arguments = XPCArray()
    }
    
    public func encode() -> XPCDictionary {
        let dictionary = XPCDictionary()
        dictionary["target"] = target
        dictionary["generics"] = genericSubstitutions
        dictionary["arguments"] = arguments
        dictionary["returnType"] = returnType
        dictionary["errorType"] = errorType
        return dictionary
    }
}

extension InvocationEnvelope: XPCConvertible {
    public static let xpcType: xpc_type_t = XPC_TYPE_DICTIONARY
    
    public init(fromXPC value: xpc_object_t) {
        self.init(XPCDictionary(fromXPC: value))
    }
    
    public func toXPC() -> xpc_object_t {
        encode().toXPC()
    }
}

public struct InvocationReturn: XPCDictionaryHolding {
    public let rawValue: XPCDictionary
    
    public init(rawValue: XPCDictionary) {
        self.rawValue = rawValue
    }
    
    public var returnData: Data? {
        get { rawValue[safe: "returnData"] }
        nonmutating set { rawValue["returnData"] = newValue }
    }
    
    public var errorData: Data? {
        get { rawValue[safe: "errorData"] }
        nonmutating set { rawValue["errorData"] = newValue }
    }
}
