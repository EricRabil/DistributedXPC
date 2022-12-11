//
//  IDSSession+Destinations.swift
//  IDSSwitchblade
//
//  Created by Eric Rabil on 12/2/22.
//

import Foundation

fileprivate extension _IDSSession {
    static let has_destinations = objc_classHasIVar("_IDSSession", name: "_destinations")
    
    var destinations: Set<String>? {
        guard _IDSSession.has_destinations else {
            return nil
        }
        return value(forKey: "_destinations") as? Set<String>
    }
}

public extension IDSSession {
    var destinations: Set<String> {
        IDSSync { destinations in
            guard let session = self._internal() else {
                return
            }
            destinations = session.destinations
        } ?? []
    }
}
