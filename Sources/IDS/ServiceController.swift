//
//  ServiceController.swift
//  IDSSwitchblade
//
//  Created by Eric Rabil on 11/30/22.
//

import Foundation
import Combine
#if canImport(IDS)
import IDS
#endif
import OSLog

protocol _ServiceController {
    static func controller(for service: String) -> Self
}

extension _ServiceController {
    init(service: String) {
        self = Self.controller(for: service)
    }
}

extension Collection where Element == IDSAccount {
    func bestAccount() -> IDSAccount? {
        if count < 2 {
            return first
        }
        return first(where: { account in
            account.isActive() && account.isEnabled()
        })
    }
}

public final class SessionController: NSObject, IDSSessionDelegate {
    public let serviceController: ServiceController
    public var service: IDSService { serviceController.service }
    public var queue: DispatchQueue { serviceController.queue }
    
    public let session: IDSSession
    
    public init(serviceController: ServiceController, session: IDSSession) {
        self.serviceController = serviceController
        self.session = session
        super.init()
        
        session.setDelegate(self, queue: queue)
    }
}

public final class ServiceController: NSObject, IDSServiceDelegate {
    public let service: IDSService
    
    fileprivate let queue = DispatchQueue(label: "com.ericrabil.ids.switchblade.service-controller")
    private let subject = PassthroughSubject<IDSMessage, Never>()
    public private(set) lazy var publisher = subject.share().eraseToAnyPublisher()
    
    private var _sessions: [String: SessionController] = [:]
    public var sessions: [String: SessionController] {
        get { queue.sync { _sessions } }
        set { queue.sync { _sessions = newValue } }
    }
    
    fileprivate var cancellables = Set<AnyCancellable>()
    
    fileprivate init(_service: String) {
        service = IDSService(service: _service)
        super.init()
        service.add(self, queue: queue)
        
        publisher.receive(on: queue).sink { [unowned self] message in
            switch message.payload {
            case .invitation(let session, let options):
                if !_sessions.keys.contains(session.uniqueID()) {
                    _sessions[session.uniqueID()] = SessionController(serviceController: self, session: session)
                }
            default:
                return
            }
        }.store(in: &cancellables)
    }
    
    public struct IDSMessage {
        public let service: IDSService
        public let account: IDSAccount?
        public let context: IDSMessageContext?
        public let fromID: String?
        
        public enum Payload {
            case data(Data)
            case message([AnyHashable: Any])
            case resource(URL, metadata: Any?)
            case unhandledProtobuf(Any)
            case pendingMessage(Int32)
            case opportunisticData(Any, identifier: String)
            case invitation(IDSSession, options: Any?)
            case delivered(String)
            case groupSessionParticipantUpdate(Any)
            case sendStatus(identifier: String, sentBytes: Int32, totalBytes: Int32)
            case groupSessionParticipantDataUpdate(Any)
            case sendCompleted(identifier: String, successfully: Bool, error: Error?)
            case opportunisticSendCompleted(identifier: String, ids: Any)
        }
        
        public let payload: Payload
    }
    
    public struct IDSEnvelope {
        public enum Payload: ExpressibleByDictionaryLiteral {
            case protobuf(IDSProtobuf)
            case message([AnyHashable: Any])
            case data(Data)
            case resource(URL, metadata: [AnyHashable: Any])
            
            public init(dictionaryLiteral elements: (AnyHashable, Any)...) {
                self = .message(Dictionary(uniqueKeysWithValues: elements))
            }
        }
        
        public var destinations: [IDSDestination]
        public var priority: Int32
        public var options: [AnyHashable: Any]
        public var account: IDSAccount
        public var payload: Payload
    }
    
    public func send(_ payload: IDSEnvelope.Payload, to destinations: [IDSDestination], priority: Int32 = 100, options: [AnyHashable: Any] = [:], account: IDSAccount? = nil) throws -> String {
        guard let account = account ?? primaryAccount else {
            return ""
        }
        return try send(IDSEnvelope(destinations: destinations, priority: priority, options: options, account: account, payload: payload))
    }
    
    public func send(_ envelope: IDSEnvelope) throws -> String {
        var error: NSError?, identifier: NSString?
        switch envelope.payload {
        case .protobuf(let protobuf):
            service.send(protobuf, from: envelope.account, to: envelope.destinations, priority: envelope.priority, identifier: &identifier, error: &error)
        case .message(let message):
            service.sendMessage(message, from: envelope.account, to: envelope.destinations, priority: envelope.priority, identifier: &identifier, error: &error)
        case .data(let data):
            service.send(data, from: envelope.account, to: envelope.destinations, priority: envelope.priority, identifier: &identifier, error: &error)
        case .resource(let url, metadata: let metadata):
            service.sendResource(at: url, metadata: metadata, to: envelope.destinations, priority: envelope.priority, identifier: &identifier, error: &error)
        }
        if let error = error {
            throw error
        }
        return identifier! as String
    }
    
    public func service(_ service: IDSService, account: IDSAccount, incomingData data: Data, fromID id: String, context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: id, payload: .data(data)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, incomingMessage message: [AnyHashable : Any], fromID id: String, context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: id, payload: .message(message)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, incomingResourceAt url: URL, fromID id: String, context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: id, payload: .resource(url, metadata: nil)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, incomingUnhandledProtobuf protobuf: Any, fromID id: String, context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: id, payload: .unhandledProtobuf(protobuf)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, incomingResourceAt url: URL, metadata: Any, fromID id: String, context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: id, payload: .resource(url, metadata: metadata)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, incomingPendingMessageOfType type: Int32, fromID id: String, context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: id, payload: .pendingMessage(type)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, incomingOpportunisticData data: Any, withIdentifier identifier: String, fromID id: String, context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: id, payload: .opportunisticData(data, identifier: identifier)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, inviteReceivedFor session: IDSSession, fromID id: String) {
        subject.send(IDSMessage(service: service, account: account, context: nil, fromID: id, payload: .invitation(session, options: nil)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, identifier: String, hasBeenDeliveredWith context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: nil, payload: .delivered(identifier)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, inviteReceivedFor session: IDSSession, fromID id: String, with context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: id, payload: .invitation(session, options: nil)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, receivedGroupSessionParticipantUpdate update: Any) {
        subject.send(IDSMessage(service: service, account: account, context: nil, fromID: nil, payload: .groupSessionParticipantUpdate(update)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, identifier: String, sentBytes: Int32, totalBytes: Int32) {
        subject.send(IDSMessage(service: service, account: account, context: nil, fromID: nil, payload: .sendStatus(identifier: identifier, sentBytes: sentBytes, totalBytes: totalBytes)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, receivedGroupSessionParticipantDataUpdate update: Any) {
        subject.send(IDSMessage(service: service, account: account, context: nil, fromID: nil, payload: .groupSessionParticipantDataUpdate(update)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, inviteReceivedFor session: IDSSession, fromID id: String, withOptions options: Any) {
        subject.send(IDSMessage(service: service, account: account, context: nil, fromID: id, payload: .invitation(session, options: options)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, identifier: String, fromID id: String, hasBeenDeliveredWith context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: id, payload: .delivered(identifier)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, identifier: String, didSendWithSuccess success: Bool, error: Error?, context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: nil, payload: .sendCompleted(identifier: identifier, successfully: success, error: error)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, identifier: String, didSendWithSuccess success: Bool, error: Error?) {
        subject.send(IDSMessage(service: service, account: account, context: nil, fromID: nil, payload: .sendCompleted(identifier: identifier, successfully: success, error: error)))
    }
    
    public func service(_ service: IDSService, account: IDSAccount, receivedGroupSessionParticipantUpdate update: Any, context: IDSMessageContext) {
        subject.send(IDSMessage(service: service, account: account, context: context, fromID: nil, payload: .groupSessionParticipantUpdate(update)))
    }
    
    public func service(_ service: IDSService, didSendOpportunisticDataWithIdentifier identifier: String, toIDs ids: Any) {
        subject.send(IDSMessage(service: service, account: nil, context: nil, fromID: nil, payload: .opportunisticSendCompleted(identifier: identifier, ids: ids)))
    }
}

extension ServiceController: _ServiceController {
    private static let queue = DispatchQueue(label: "com.ericrabil.ids.switchblade.service-controller")
    private static var controllers: [String: ServiceController] = [:]
    
    static func controller(for service: String) -> ServiceController {
        queue.sync {
            if let controller = controllers[service] {
                return controller
            }
            let controller = ServiceController(_service: service)
            controllers[service] = controller
            return controller
        }
    }
}

public extension ServiceController {
    var accounts: Set<IDSAccount> {
        service.accounts()
    }
    
    var primaryAccount: IDSAccount? {
        accounts.bestAccount()
    }
}

extension ServiceController.IDSMessage.Payload: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .data(let data):
            return (data as NSData).debugDescription
        case .message(let dictionary):
            return (dictionary as NSDictionary).debugDescription
        case .resource(let URL, let metadata):
            return (["URL": URL, "metadata": metadata] as NSDictionary).debugDescription
        case .unhandledProtobuf(let any):
            return String(describing: any)
        case .pendingMessage(let int32):
            return "<pending message: \(int32)>/"
        case .opportunisticData(let data, let identifier):
            return """
                   <opportunistic \(String(describing: data)) id="\(identifier)"/>
                   """
        case .invitation(let invitation, options: let options):
            return """
                   <invitation session=\(invitation.debugDescription) options=\(options.map(String.init(describing:)) ?? "nil")/>
                   """
        case .delivered(let identifier):
            return """
                   <delivered id=\(identifier)/>
                   """
        case .groupSessionParticipantUpdate(let update):
            return """
                   <group-session-participant-update=\(String(describing: update))/>
                   """
        case .sendStatus(identifier: let identifier, sentBytes: let sentBytes, totalBytes: let totalBytes):
            return """
                   <send-status id=\(identifier) sent=\(sentBytes) total=\(totalBytes)/>
                   """
        case .groupSessionParticipantDataUpdate(let update):
            return """
                   <group-session-participant-data-update=\(String(describing: update))/>
                   """
        case .sendCompleted(identifier: let identifier, successfully: let successfully, error: let error):
            return """
                   <send-complete id="\(identifier)" success=\(successfully) error=\(error.map(String.init(describing:)) ?? "nil")/>
                   """
        case .opportunisticSendCompleted(identifier: let identifier, ids: let ids):
            return """
                   <opportunistic-send-complete id="\(identifier)" ids=\(String(describing: ids))/>
                   """
        }
    }
}

extension ServiceController.IDSMessage: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        <IDSMessage topic="\(service.serviceIdentifier())" account="\(account?.uniqueID() ?? "")" fromID="\(fromID ?? "")" context=\(context.map(\._debugDescription) ?? "nil") payload=\(payload.debugDescription)/>
        """
    }
}

public extension ServiceController {
    internal class Monitor {
        static let shared = Monitor()
        
        let log = Logger(subsystem: "com.ericrabil.ids.switchblade", category: "Monitor")
        
        var monitors: [ServiceController: AnyCancellable] = [:]
        
        func monitor(_ service: ServiceController) {
            monitors[service] = service.publisher.sink { [log] message in
                log.info("\(message.debugDescription)")
            }
        }
    }
    
    func monitor() {
        Monitor.shared.monitor(self)
    }
}

public extension ServiceController {
    func createSession(with destinations: Set<IDSDestination>, account: IDSAccount? = nil, options: [AnyHashable: Any] = [:]) -> SessionController {
        let session = IDSSession(account: account ?? primaryAccount ?? IDSAccount(), destinations: destinations, transportType: 1)
        let controller = SessionController(serviceController: self, session: session)
        sessions[session.uniqueID()] = controller
        return controller
    }
}
