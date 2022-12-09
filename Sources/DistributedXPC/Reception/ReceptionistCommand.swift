//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import XPCCollections

struct ReceptionistCommand: XPCDictionaryHolding {
    let rawValue: XPCDictionary
    
    enum CommandID: Int, XPCConvertible {
        case invocation
        case invocationReturn
    }
    
    var command: CommandID? {
        get { rawValue[safe: "command"] }
        nonmutating set { rawValue["command"] = newValue }
    }
    
    var id: UUID? {
        get { rawValue[safe: "uuid"] }
        nonmutating set { rawValue["uuid"] = newValue }
    }
    
    var envelope: InvocationEnvelope? {
        get { rawValue[safe: "envelope"] }
        nonmutating set { rawValue["envelope"] = newValue }
    }
    
    var returnEnvelope: InvocationReturn? {
        get { rawValue[safe: "return"] }
        nonmutating set { rawValue["return"] = newValue }
    }
    
    var actorID: XPCActorSystem.ActorID? {
        get { rawValue[safe: "actor"] }
        nonmutating set { rawValue["actor"] = newValue }
    }
    
    func isValid() -> Bool {
        xpc_get_type(rawValue.rawValue) == XPC_TYPE_DICTIONARY && command != nil && id != nil && actorID != nil
    }
}
