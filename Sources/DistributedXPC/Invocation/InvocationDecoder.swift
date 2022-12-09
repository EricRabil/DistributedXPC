//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import Distributed

public struct XPCInvocationDecoder: DistributedTargetInvocationDecoder {
    public typealias SerializationRequirement = Codable
    
    let system: XPCActorSystem
    let envelope: InvocationEnvelope
    var index = 0
    
    public mutating func decodeGenericSubstitutions() throws -> [Any.Type] {
        return try envelope.genericSubstitutions.indices.map { index in
            guard let name = envelope.genericSubstitutions[safe: index] as String? else {
                throw SerializationError.malformedEnvelope
            }
            guard let type = SwiftABI.deserializeType(name) else {
                throw SerializationError.notAbleToDeserialize(hint: name)
            }
            return type
        }
    }
    
    public mutating func decodeNextArgument<Argument: SerializationRequirement>() throws -> Argument {
        guard index < envelope.arguments.count else {
            throw SerializationError.notEnoughArgumentsEncoded(expected: index + 1, have: envelope.arguments.count)
        }
        
        guard let data = envelope.arguments[safe: index] as Data? else {
            throw SerializationError.malformedEnvelope
        }
        
        index += 1
        let argument: [Argument] = try system.serialization.deserialize(data)
        return argument[0]
    }
    
    public mutating func decodeErrorType() throws -> Any.Type? {
        guard let errorType = envelope.errorType else {
            return nil
        }
        guard let type = SwiftABI.deserializeType(errorType) else {
            throw SerializationError.notAbleToDeserialize(hint: errorType)
        }
        return type
    }
    
    public mutating func decodeReturnType() throws -> Any.Type? {
        guard let returnType = envelope.returnType else {
            return nil
        }
        guard let type = SwiftABI.deserializeType(returnType) else {
            throw SerializationError.notAbleToDeserialize(hint: returnType)
        }
        return type
    }
}
