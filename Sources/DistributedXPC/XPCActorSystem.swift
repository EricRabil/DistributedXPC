import Distributed
import Foundation
import XPCCollections

public class XPCActorSystem: DistributedActorSystem, @unchecked Sendable {
    public typealias ActorID = UUID
    public typealias InvocationEncoder = XPCInvocationEncoder
    public typealias InvocationDecoder = XPCInvocationDecoder
    public typealias ResultHandler = XPCInvocationResultHandler
    public typealias SerializationRequirement = Codable
    public typealias CallID = UUID
    
    let serialization: Serialization = PropertyListSerialization()
    let receptionist: XPCRemoteReceptionist
    
    init(receptionist: XPCRemoteReceptionist) {
        self.receptionist = receptionist
        receptionist.setInvocationHandler { invocation, actorID, invocationID in
            var decoder = XPCInvocationDecoder(system: self, envelope: invocation)
            
            guard let actor = self.registry[actorID] else {
                fatalError()
            }
            
            let handler = XPCInvocationResultHandler(callID: invocationID, system: self)
            do {
                try await self.executeDistributedTarget(on: actor, target: RemoteCallTarget(invocation.target!), invocationDecoder: &decoder, handler: handler)
            } catch {
                fatalError()
            }
            return await handler.promise.result
        }
    }
    
    private let lock = DispatchLock()
    
    private var reserved: Set<ActorID> = Set()
    private var registry: [ActorID: any DistributedActor] = [:]
    
    private var isEmpty: Bool {
        reserved.isEmpty && registry.isEmpty
    }
    
    private func generateID() -> UUID {
        if isEmpty {
            return XPCDefaultActorID
        }
        return UUID()
    }
    
    public func resolve<Act>(id: ActorID, as actorType: Act.Type) throws -> Act? where Act : DistributedActor, ActorID == Act.ID {
        lock.withLock {
            registry[id] as? Act
        }
    }
    
    public func assignID<Act>(_ actorType: Act.Type) -> ActorID where Act : DistributedActor, ActorID == Act.ID {
        lock.withLock {
            let element = self.generateID()
            reserved.insert(element)
            return element
        }
    }
    
    public func resignID(_ id: ActorID) {
        lock.withLock {
            registry.removeValue(forKey: id)
            reserved.remove(id)
        }
    }
    
    public func makeInvocationEncoder() -> XPCInvocationEncoder {
        XPCInvocationEncoder(system: self)
    }
    
    public func actorReady<Act: DistributedActor>(_ actor: Act) where Act.ID == ActorID {
        lock.withLock {
            guard self.reserved.remove(actor.id) != nil else {
                fatalError("Attempted to ready actor for unknown ID! Was: \(actor.id), reserved (known) IDs: \(self.reserved)")
            }
            
            registry[actor.id] = actor
        }
    }
}

extension XPCActorSystem {
    public struct SystemError: Error {
        public enum ErrorType: Codable {
            case unexpectedlyEmptyInvocationReturn
            case invocationThrew
        }
        
        public var type: ErrorType
        public var actorID: UUID?
        public var invocation: InvocationEnvelope?
        public var invocationReturn: InvocationReturn?
    }
}

extension XPCActorSystem {
    public func remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res
    where Act: DistributedActor,
          Act.ID == ActorID,
          Err: Error,
          Res: Codable {
              invocation.envelope.target = target.identifier
              let response = await receptionist.sendInvocation(invocation.envelope, actor: actor.id)
              
              if let returnData = response.returnData {
                  let returnValue = try serialization.deserialize(returnData) as [Res]
                  return returnValue[0]
              }
              
              if let _ = response.errorData {
                  throw SystemError(type: .invocationThrew, actorID: actor.id, invocation: invocation.envelope, invocationReturn: response)
              }
              
              throw SystemError(type: .unexpectedlyEmptyInvocationReturn, actorID: actor.id, invocation: invocation.envelope, invocationReturn: response)
          }
    
    public func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws where Act: DistributedActor,
                         Act.ID == ActorID,
                         Err: Error {
                             invocation.envelope.target = target.identifier
                             let response = await receptionist.sendInvocation(invocation.envelope, actor: actor.id)
                             
                             if let _ = response.errorData {
                                 throw SystemError(type: .invocationThrew, actorID: actor.id, invocation: invocation.envelope, invocationReturn: response)
                             }
                         }
}
