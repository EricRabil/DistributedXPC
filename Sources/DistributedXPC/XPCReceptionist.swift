//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import Distributed

protocol XPCReceptionist {
    func lookup<P: XPCActor>(_ actorID: XPCActorSystem.ActorID) -> P
    func register<P: XPCActor>(_ actor: P)
}

