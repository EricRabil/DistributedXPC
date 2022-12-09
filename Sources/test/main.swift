//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/8/22.
//

import Foundation
@_spi(testing) import DistributedXPC
import XPCCollections
import Distributed

let reception = XPCLocalReceptionist()

distributed actor ActorTest: XPCActor {
    init?(actorSystem: ActorSystem, connection: XPCConnection) {
        self.actorSystem = actorSystem
    }
    
    var pp = 0
    
    distributed func test(_ arg: String) -> String {
        print("hi \(arg)")
        pp += 1
        return "you are stupid \(pp)"
    }
}

Task {
    await reception.listen("com.ericrabil.actor-test", defaultActor: ActorTest.self)

    let otherProcessReception = XPCLocalReceptionist()
    
    let myRemoteTest: ActorTest = try await otherProcessReception.lookup(service: "com.ericrabil.actor-test")
    Task {
        for _ in 0..<5 {
            print(try! await myRemoteTest.test("hey there"))
        }
    }
}

dispatchMain()
