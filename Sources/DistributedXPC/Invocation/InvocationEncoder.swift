//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import Distributed

public struct XPCInvocationEncoder: DistributedTargetInvocationEncoder {
    public typealias SerializationRequirement = Codable
    
    let system: XPCActorSystem
    
    var envelope = InvocationEnvelope()
    
    public mutating func recordGenericSubstitution<T>(_ type: T.Type) throws {
        let typeName = SwiftABI.serializeType(type)
        envelope.genericSubstitutions.append(typeName)
    }
    
    public mutating func recordArgument<Value: Codable>(_ argument: RemoteCallArgument<Value>) throws {
        let serialized = try self.system.serialization.serialize([argument.value])
        envelope.arguments.append(serialized)
    }
    
    public mutating func recordErrorType<E: Error>(_ type: E.Type) throws {
        envelope.errorType = SwiftABI.serializeType(type)
    }
    
    public mutating func recordReturnType<R: SerializationRequirement>(_ type: R.Type) throws {
        envelope.returnType = SwiftABI.serializeType(type)
    }
    
    public mutating func doneRecording() throws {
        
    }
}
