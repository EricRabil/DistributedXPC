//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation

struct DispatchLock {
    private let semaphore: DispatchSemaphore
    
    init() {
        semaphore = DispatchSemaphore(value: 1)
    }
    
    func withLock<P>(_ callback: () throws -> P) rethrows -> P {
        semaphore.wait()
        defer { semaphore.signal() }
        return try callback()
    }
}

struct AsyncDispatchLock {
    private let queue: OperationQueue
    
    init(queue: DispatchQueue = .global()) {
        self.queue = OperationQueue()
        self.queue.underlyingQueue = queue
        self.queue.maxConcurrentOperationCount = 1
        self.queue.isSuspended = false
    }
    
    func withLock(_ callback: @escaping () -> ()) {
        queue.addOperation(callback)
    }
    
    func sync<P>(_ callback: @escaping () -> P) -> P {
        var result: P!
        withLock {
            result = callback()
        }
        queue.waitUntilAllOperationsAreFinished()
        return result
    }
}
