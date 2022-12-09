//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation

public protocol Serialization {
    func serialize<P: Codable>(_ value: P) throws -> Data
    func deserialize<P: Codable>(_ data: Data) throws -> P
}
