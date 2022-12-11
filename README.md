# XPC Distributed Actors System Design

## Requirements & Goals

### Functional Requirements
1. Clients should be able to query the `DistributedActorSystem` for a given Mach service name and receive an actor allowing them to interface with said service.
2. Each client will have their own `DistributedActorSystem` which facilitates the lookup with the bootstrap system.

### Non-Functional Requirements
1. The system should be highly reliable - requests to an offline service should be fired upon next availability.
2. The system should be as available as `NSXPCConnection` in that services will be launched if they are offline when requested. 

### Extended Requirements
1. How can we leverage the XPC serialization APIs to facilitate cross-machine XPC connections?
2. Would it be feasible to make the Mach services available over HTTP APIs in addition to XPC? How would this look?
3. We may want this system to be cross-compatible with NSXPC. How can we effectively implement this bridging with Objective-C? Are their naming conversions we could piggy back off of from the Swift standard library that would assist in this? If this is not possible or feasible, why is that the case?

## Considerations
- What happens when a request is sent to a connection that has been invalidated?
	- We can place the request in a backlog that will be executed upon reconnection, and indicate to the system that we should reconnect if we are not doing so already.
- How can actors that are publishing a service validate that the client has the appropriate entitlements?
	- We can create optional protocols that actors may conform to, where the actor can inspect the audit token of the incoming connection. However, this does not take into account remote connections. For this case, we could have remote connections send their code signature blob and validate it against local policy.
- How should our receptionist system look? Should there be a receptionist for all systems (both local and remote), or should there be a single receptionist which optionally allows looking up services on remote systems?

## Capacity & Constraints
- Let's say Apple intended to ultimately utilize this actor system for all XPC connections on the system. How will it perform under load, especially when many APIs are initializing their connections at startup? How will locking interfere with this?

## System APIs
### XPCReceptionist
```swift
class XPCReceptionist<ActorSystem: DistributedActorSystem> {
    /// Represents the endpoint where XPC services should be resolved
    enum Remote {
        /// Perform XPC resolution on the local device
        case localSystem
        /// Perform XPC resolution on the device with the given IDS identifier
        case device(String)
    }

    let system: ActorSystem

    func lookup<P>(_ service: String, remote: Remote = .localSystem) async -> P
	    where P: DistributedActor, P.ActorSystem == ActorSystem

    func checkin<P>(_ service: String, actor: P)
	    where P: DistributedActor, P.ActorSystem == ActorSystem
}
```
The `XPCReceptionist` acts as the gateway between in-task and out-of-task services, and should support both on-device and cross-device service resolution. Cross-device service resolution should be powered by IDS, and may reuse an existing alloy topic to achieve this during the prototyping stage. The reused topic should be limited 
to devices on the same account.

The `XPCReceptionist` interfaces with the `DistributedActorSystem` for all local service requests. For remote (cross-device) requests, it will call out to `xpcidsd` service, which manages IDS sessions for actor connections.

## High Level Design
At a high level, our system looks like this:
```
Client -> XPCReceptionist -> XPCActorSystem -> bootstrap_lookup -> XPCActorSystem -> Service
		   \- `xpcidsd` (local)	 	`xpcidsd` (remote) -/
			      \-    IDSSesion	  -/
```
Service lookups have two paths: the local path, and the remote path.
	- For local paths, service lookups will flow from the receptionist to the actor system, which will query the bootstrap service. If successful, the actor system will communicate with the remote actor system on the designated Mach port and attempt to connect to the remote service.
	- For remote paths, service lookups will flow from the receptionist to `xpcidsd`, which manages IDS sessions for actor connections. Each mach service name will have exactly one IDS session.

## Component Design
###  Application Layer
The application layer interfaces with both local and remote transport layers, hiding the underlying transport systems from the clients. This layer is also responsible for crafting the envelope that contains the actual request information.

#### What does the envelope contain?
1. The invocation message (or result, if we are returning from an invocation)
2. The ID of the remote actor
3. The mach service name
#### How is the envelope encoded?
The envelope is encoded into an XPC message. However, all arguments and return values are constrained to conform to the `Codable` protocol, and we will be passing those valued as bplist-encoded data. We may want to use the same encoding that is used for XPC, which is a more lightweight variant of the public binary plist format.


### Tranport Layer

#### Local
For local requests, transporting envelopes is fairly straightforward. We will obtain a connection from the bootstrap server if we do not have one already. Then, we will send our envelope. Assuming there is an actor system on the other end of the mach service, it will then check its internal table for an actor that is listening on 
the requested mach service. If an actor exists, it will forward the invocation. If not, it will return with a system-level error.
**How can we reconcile invocations to a service that has no actor?** This is highly application-specific. Applications may define an initializer that can lazily load an actor, in which case recovery is possible. Otherwise, the request must fail.

#### Remote
For remote requests, there are an additional three steps to the transport layer. Systems supporting this actor system will contain a per-user daemon `xpcidsd`, which is responsible for transporting envelopes between devices. `xpcidsd` will maintain exactly one connection per-device, and have an additional envelope system used to 
route actor envelopes to the correct service.

When an envelope is sent to a device for the first time, `xpcidsd` will request to start a session with the remote device. Assuming `xpcidsd` is running on the remote device, and the devices trust each other, the connection will be opened. The local daemon will then send a message containing the envelope and routing information. 
The remote daemon will then assert a connection to the mach service by querying the bootstrap server, and then relay the envelope.

**Isn't `xpcidsd` a single point of failure?** Yes. While each process could maintain its own sessions, this would be wasteful and a security risk. Granting access to IDS is a very sensitive decision and should be limited to as few services as possible. By creating a daemon to facilitate remote transports, actor systems can safely 
interact with remote devices without unabstracted access to IDS.

**What happens if the session is interrupted?** The daemon will begin staging envelopes and re-initiate a session with the device. After an undefined amount of time, the daemon may begin to refuse requests to local clients to prevent an overflow of the buffer, and to indicate to the user that the connection has been irreparably 
severed.

## Security & Permissions

### Local
Local processes will be confined to the services that they may reach according to their entitlements. Because they are interacting directly with the bootstrap server, their scope will be determined as it would by any other mach connection.

### Remote
Remote processes will require an application-level implementation of entitlement checks. `xpcidsd` will require unobstructed access to mach services in the user bootstrap domains to effectively evaluate these permissions. Messages exchanged with devices will contain the `csblob` of the processes, and actor connections will only be 
established if the `csblob` passes the local policy for mach service connections.

**Remote connections will not have access to global services. They may only access services within the user domain. This is because connections are established with trusted devices for the current Apple ID, and a device may have multiple Apple IDs signed in. CS blobs are still evaluated, but exceptions for global services are not 
respected.**
