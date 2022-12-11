//
//  IDSConnection+ServiceToken.swift
//  IDSSwitchblade
//
//  Created by Eric Rabil on 12/1/22.
//

import Foundation

fileprivate extension _IDSConnection {
    static let has_serviceToken = objc_classHasIVar("_IDSConnection", name: "_serviceToken")
    
    var serviceToken: String? {
        guard _IDSConnection.has_serviceToken else {
            return nil
        }
        return value(forKey: "_serviceToken") as? String
    }
}

public extension IDSConnection {
    var serviceToken: String? {
        IDSSync { serviceToken in
            guard let connection = self._internal() else {
                return
            }
            serviceToken = connection.serviceToken
        }
    }
}

public extension IDSConnection {
    var capabilities: IDSListenerCap {
        get {
            guard let serviceToken = serviceToken else {
                return []
            }
            return IDSDaemonController.sharedInstance().capabilities(forListenerID: serviceToken)
        }
        set {
            guard let serviceToken = serviceToken else {
                return
            }
            IDSDaemonController.sharedInstance().setCapabilities(newValue, forListenerID: serviceToken, shouldLog: true)
        }
    }
}
