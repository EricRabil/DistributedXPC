//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import OSLog
import XPCCollections

public enum XPCActorRoute: Hashable, Codable, Sendable {
    /// Use the local bootstrap system
    case local
    /// The IDS device identifier of the remote receptionist
    case remote(id: String)
}

public struct XPCAddress: Hashable, Codable, Sendable {
    public let port: String
    public let privileged: Bool
    
    var flags: UInt64 {
        if privileged {
            return UInt64(XPC_CONNECTION_MACH_SERVICE_PRIVILEGED)
        } else {
            return 0
        }
    }
    
    func createConnection() -> xpc_connection_t {
        return xpc_connection_create_mach_service(port, nil, flags)
    }
}

actor XPCLocalBroker {
    var connections: [XPCAddress: xpc_connection_t] = [:]
    
    func connection(for address: XPCAddress) -> xpc_connection_t {
        if let connection = connections[address] {
            return connection
        }
        let connection = address.createConnection()
        connections[address] = connection
        return connection
    }
}

func withXPCDescription<P>(_ object: xpc_object_t, _ callback: (UnsafeMutablePointer<CChar>) throws -> P) rethrows -> P {
    let pointer = xpc_copy_description(object)
    defer { free(pointer) }
    return try callback(pointer)
}
