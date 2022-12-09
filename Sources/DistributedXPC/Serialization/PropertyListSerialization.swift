//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation

public struct PropertyListSerialization: Serialization {
    let encoder: PropertyListEncoder
    let decoder: PropertyListDecoder
    
    init() {
        encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        
        decoder = PropertyListDecoder()
    }
    
    public func serialize<P>(_ value: P) throws -> Data where P : Decodable, P : Encodable {
        try encoder.encode(value)
    }
    
    public func deserialize<P>(_ data: Data) throws -> P where P : Decodable, P : Encodable {
        try decoder.decode(P.self, from: data)
    }
}
