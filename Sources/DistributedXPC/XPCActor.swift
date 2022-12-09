//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import Distributed

public protocol XPCActor: DistributedActor where ActorSystem == XPCActorSystem, ID == ActorSystem.ActorID, SerializationRequirement == Codable {
    init?(actorSystem: ActorSystem, connection: XPCConnection)
}
