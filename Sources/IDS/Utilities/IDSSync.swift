//
//  IDSSync.swift
//  IDSSwitchblade
//
//  Created by Eric Rabil on 12/1/22.
//

import Foundation

fileprivate let _IDSInternalQueueController: IDSInternalQueueController.Type! = _ERClassFromString("IDSInternalQueueController")

func IDSSync<P>(_ initialValue: P, _ callback: @escaping (inout P) -> ()) -> P {
    let queueController = _IDSInternalQueueController.sharedInstance()
    queueController.assertQueueIsNotCurrent()
    
    var initialValue: P = initialValue
    queueController.perform({
        callback(&initialValue)
    }, waitUntilDone: true)
    return initialValue
}

func IDSSync<P>(_ callback: @escaping (inout P?) -> ()) -> P? {
    IDSSync(nil, callback)
}
