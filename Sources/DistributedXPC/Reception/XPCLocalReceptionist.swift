//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import XPCCollections
import OSLog
import Distributed

private let log = Logger(subsystem: "com.ericrabil.distributed-xpc", category: "LocalReception")

public let XPCDefaultActorID = UUID(uuidString: "66ACD257-449F-4887-B6CF-92E231A54AE9")!

public actor XPCLocalReceptionist {
    private var listeners: [String: XPCConnection] = [:]
    @_spi(testing) public var receptionistsForLocalServices: [String: Set<XPCRemoteReceptionist>] = [:]
    private var remoteReceptionists: [String: XPCRemoteReceptionist] = [:]
    
    public init() {
        
    }
    
    public func listen<Act: XPCActor>(_ service: String, defaultActor: Act.Type, privileged: Bool = false) {
        let listener = XPCConnection(machService: service, privileged: privileged, listener: true)
        listeners[service] = listener
        listener.setEventHandler { connection in
            guard xpc_get_type(connection) == XPC_TYPE_CONNECTION else {
                let description = withXPCDescription(connection) { String(cString: $0) }
                log.warning("Unexpected message over receptionist listener \(service): \(description)")
                return
            }
            let connection = XPCConnection(rawValue: connection)
            let receptionist = XPCRemoteReceptionist(connection: connection, service: service)
            guard let actor = Act(actorSystem: receptionist.system, connection: connection) else {
                connection.cancel()
                return
            }
            receptionist.defaultActor = actor
            self.receptionistsForLocalServices[service, default: Set()].insert(receptionist)
        }
        listener.resume()
        log.info("Listening for receptionist requests over \(service)")
    }
    
    public func connect(_ service: String, privileged: Bool = false, tickle: Bool = false) -> XPCActorSystem {
        if let existing = remoteReceptionists.removeValue(forKey: service) {
            existing.cancel()
        }
        let connection = XPCConnection(machService: service, privileged: privileged)
        let receptionist = XPCRemoteReceptionist(connection: connection, service: service)
        if tickle {
            _ = connection.sendMessageWithReply(XPCDictionary().rawValue)
        }
        remoteReceptionists[service] = receptionist
        return receptionist.system
    }
    
    private func actorSystem(for service: String, privileged: Bool = false, tickle: Bool = false) -> XPCActorSystem {
        if let existing = remoteReceptionists[service] {
            return existing.system!
        } else {
            return connect(service, privileged: privileged, tickle: tickle)
        }
    }
    
    public func lookup<P: DistributedActor>(service: String, privileged: Bool = false, id: XPCActorSystem.ActorID = XPCDefaultActorID) throws -> P where P.ID == XPCActorSystem.ActorID, P.ActorSystem == XPCActorSystem {
        return try P.resolve(id: id, using: actorSystem(for: service, privileged: privileged))
    }
}
