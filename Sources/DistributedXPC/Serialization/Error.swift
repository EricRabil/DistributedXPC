//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation

enum SerializationError: Error {
    case notAbleToDeserialize(hint: String?)
    case malformedEnvelope
    case notEnoughArgumentsEncoded(expected: Int, have: Int)
}
