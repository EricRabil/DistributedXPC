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

fileprivate let log = Logger(subsystem: "com.ericrabil.distributed-xpc", category: "RemoteReception")

public class XPCRemoteReceptionist {
    var connection: XPCConnection
    let service: String
    
    @_spi(testing) public private(set) var system: XPCActorSystem!
    
    typealias InvocationHandler = (_ envelope: InvocationEnvelope, _ actorID: XPCActorSystem.ActorID, _ invocationID: UUID) async -> InvocationReturn
    static let defaultInvocationHandler: InvocationHandler = { _,_,_ in InvocationReturn() }
    
    private var invocationHandler: InvocationHandler = defaultInvocationHandler
    private var pendingInvocations: [UUID: AsyncDispatchPromise<InvocationReturn>] = [:]
    
    internal var defaultActor: (any DistributedActor)?
    
    init(connection: XPCConnection, service: String) {
        self.connection = connection
        self.service = service
        
        system = XPCActorSystem(receptionist: self)
        
        connection.setEventHandler(handle(message:))
        connection.resume()
    }
    
    private func nopInvalid(_ message: xpc_object_t) {
        let description = withXPCDescription(message) { String(cString: $0) }
        log.warning("Unexpected message over receptionist listener \(self.service) from pid \(self.connection.pid): \(description)")
        if let reply = xpc_dictionary_create_reply(message).map(XPCDictionary.init(fromXPC:)) {
            reply["error"] = "invalid"
            connection.sendMessage(reply)
        }
        return
    }
    
    private func handle(message: xpc_object_t) {
        let command = ReceptionistCommand(fromXPC: message)
        guard command.isValid() else {
            return nopInvalid(message)
        }
        log.info("Received command \(command.command!.rawValue) from \(self.connection.description)")
        switch command.command {
        case .invocation:
            guard let envelope = command.envelope else {
                return nopInvalid(message)
            }
            Task {
                let returnValue = await self.invocationHandler(envelope, command.actorID!, command.id!)
                let response = ReceptionistCommand()
                response.id = command.id
                response.actorID = command.actorID
                response.command = .invocationReturn
                response.returnEnvelope = returnValue
                self.connection.sendMessage(response)
            }
        case .invocationReturn:
            guard let returnEnvelope = command.returnEnvelope else {
                return nopInvalid(message)
            }
            guard let pending = pendingInvocations.removeValue(forKey: command.id!) else {
                log.warning("Received invocation return for unknown invocation \(command.id!)")
                return
            }
            pending.fulfill(with: returnEnvelope)
        default:
            return
        }
    }
    
    private func send(_ invocation: InvocationEnvelope, actor: XPCActorSystem.ActorID, id: UUID) {
        let message = ReceptionistCommand()
        message.command = .invocation
        message.id = id
        message.envelope = invocation
        message.actorID = actor
        connection.sendMessage(message)
    }
    
    func sendInvocation(_ invocation: InvocationEnvelope, actor: XPCActorSystem.ActorID) async -> InvocationReturn {
        let invocationID = UUID()
        let promise = AsyncDispatchPromise<InvocationReturn>()
        pendingInvocations[invocationID] = promise
        send(invocation, actor: actor, id: invocationID)
        return await promise.result
    }
    
    func setInvocationHandler(_ callback: @escaping InvocationHandler) {
        invocationHandler = callback
    }
    
    func cancel() {
        connection.cancel()
        invocationHandler = Self.defaultInvocationHandler
        for invocation in pendingInvocations.values {
            invocation.fulfill(with: InvocationReturn())
        }
    }
}

extension XPCRemoteReceptionist: Hashable {
    public static func ==(lhs: XPCRemoteReceptionist, rhs: XPCRemoteReceptionist) -> Bool {
        lhs.connection == rhs.connection
    }
    
    public func hash(into hasher: inout Hasher) {
        connection.hash(into: &hasher)
    }
}
