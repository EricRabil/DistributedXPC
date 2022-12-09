//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation
import XPC
import XPCCollections

public struct XPCConnection: XPCHolding {
    public static var xpcType: xpc_type_t { XPC_TYPE_CONNECTION }
    
    public let rawValue: xpc_connection_t
    
    public init(rawValue: xpc_connection_t) {
        self.rawValue = rawValue
    }
}

public extension XPCConnection {
    init(machService: UnsafePointer<CChar>, queue: DispatchQueue? = nil, privileged: Bool = false, listener: Bool = false, flags: UInt64 = 0) {
        var flags = flags
        if privileged {
            flags |= UInt64(XPC_CONNECTION_MACH_SERVICE_PRIVILEGED)
        }
        if listener {
            flags |= UInt64(XPC_CONNECTION_MACH_SERVICE_LISTENER)
        }
        rawValue = xpc_connection_create_mach_service(machService, queue, flags)
    }
    
    init(_ name: UnsafePointer<CChar>?, queue: DispatchQueue? = nil) {
        rawValue = xpc_connection_create(name, queue)
    }
    
    init(endpoint: xpc_endpoint_t) {
        rawValue = xpc_connection_create_from_endpoint(endpoint)
    }
}

public extension XPCConnection {
    var euid: uid_t {
        xpc_connection_get_euid(rawValue)
    }
    
    var egid: gid_t {
        xpc_connection_get_egid(rawValue)
    }
    
    var pid: pid_t {
        xpc_connection_get_pid(rawValue)
    }
    
    var asid: au_asid_t {
        xpc_connection_get_asid(rawValue)
    }
}

public extension XPCConnection {
    func suspend() {
        xpc_connection_suspend(rawValue)
    }
    
    func resume() {
        xpc_connection_resume(rawValue)
    }
    
    func activate() {
        xpc_connection_activate(rawValue)
    }
    
    func cancel() {
        xpc_connection_cancel(rawValue)
    }
}

public extension XPCConnection {
    func setEventHandler(_ callback: @escaping (xpc_object_t) -> ()) {
        xpc_connection_set_event_handler(rawValue, callback)
    }
    
    func setTargetQueue(_ queue: DispatchQueue?) {
        xpc_connection_set_target_queue(rawValue, queue)
    }
}

public extension XPCConnection {
    func sendMessage(_ message: xpc_object_t) {
        xpc_connection_send_message(rawValue, message)
    }
    
    func sendMessage(_ message: XPCConvertible) {
        sendMessage(message.toXPC())
    }
    
    func barrier(_ callback: @escaping () -> ()) {
        xpc_connection_send_barrier(rawValue, callback)
    }
}

public extension XPCConnection {
    func sendMessageWithReply(_ message: xpc_object_t, replyQueue: DispatchQueue? = nil, handler: @escaping xpc_handler_t) {
        xpc_connection_send_message_with_reply(rawValue, message, replyQueue, handler)
    }
    
    func sendMessageWithReply(_ message: xpc_object_t) -> xpc_object_t {
        xpc_connection_send_message_with_reply_sync(rawValue, message)
    }
}

public extension XPCConnection {
    var name: String? {
        xpc_connection_get_name(rawValue).map(String.init(cString:))
    }
}
