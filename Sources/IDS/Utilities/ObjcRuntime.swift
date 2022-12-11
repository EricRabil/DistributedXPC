//
//  ObjcRuntime.swift
//  IDSSwitchblade
//
//  Created by Eric Rabil on 12/1/22.
//

import Foundation

func objc_classHasIVar(_ className: String, name: String) -> Bool {
    guard let cls = NSClassFromString(className) else {
        return false
    }
    
    var ivarCount: UInt32 = 0
    if let ivars = class_copyIvarList(cls, &ivarCount).map({ UnsafeMutableBufferPointer(start: $0, count: Int(ivarCount)) }) {
        for ivar in ivars {
            if let name = ivar_getName(ivar), strcmp(name, name) == 0 {
                return true
            }
        }
        ivars.deallocate()
    }
    
    return false
}

func _ERClassFromString<P: AnyObject>(_ name: String) -> P.Type! {
    NSClassFromString(name).map { unsafeBitCast($0, to: P.Type.self) }
}
