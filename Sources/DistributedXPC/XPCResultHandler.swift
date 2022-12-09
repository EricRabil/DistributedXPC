//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import Distributed
import XPCCollections

public struct XPCInvocationResultHandler: DistributedTargetInvocationResultHandler {
    public typealias SerializationRequirement = Codable
    
    let callID: XPCActorSystem.CallID
    let system: XPCActorSystem
    
    let promise = AsyncDispatchPromise<InvocationReturn>()
    
    public func onReturnVoid() async throws {
        promise.fulfill(with: InvocationReturn())
    }
    
    public func onReturn<Success: Codable>(value: Success) async throws {
        let invocationReturn = InvocationReturn()
        invocationReturn.returnData = try system.serialization.serialize([value])
        promise.fulfill(with: invocationReturn)
    }
    
    public func onThrow<Err: Error>(error: Err) async throws {
        let invocationReturn = InvocationReturn()
        invocationReturn.errorData = Data("help".utf8)
        promise.fulfill(with: invocationReturn)
    }
}
