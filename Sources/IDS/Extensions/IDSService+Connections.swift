//
//  IDSService+Connections.swift
//  IDSSwitchblade
//
//  Created by Eric Rabil on 12/1/22.
//

import Foundation

fileprivate extension _IDSService {
    static let has_uniqueIDToConnection = objc_classHasIVar("_IDSService", name: "_uniqueIDToConnection")
    
    var uniqueIDToConnection: [String: IDSConnection] {
        guard _IDSService.has_uniqueIDToConnection else {
            return [:]
        }
        return value(forKey: "_uniqueIDToConnection") as? [String: IDSConnection] ?? [:]
    }
}


public extension IDSService {
    func connection(for account: IDSAccount) -> IDSConnection? {
        IDSSync { connection in
            guard let service = self._internal() else {
                return
            }
            guard let account = account._internal() else {
                return
            }
            connection = service.uniqueIDToConnection[account.uniqueID()]
        }
    }
}

public extension IDSConnection {
    var commands: Set<NSNumber> {
        get {
            serviceToken.map(IDSDaemonController.sharedInstance().commands(forListenerID:)) ?? []
        }
        set {
            serviceToken.map {
                IDSDaemonController.sharedInstance().setCommands(newValue, forListenerID: $0)
            }
        }
    }
}
