//
//  File.swift
//  
//
//  Created by Eric Rabil on 12/10/22.
//

import Foundation

class DispatchPromise<T> {
    enum Result {
        case success(T)
        case failure(Error)
    }
    
    enum _Result {
        case result(Result)
        case pending
    }
    
    typealias Callback = (Result) -> ()
    
    private let queue: DispatchQueue
    private lazy var lock: AsyncDispatchLock = AsyncDispatchLock(queue: queue)
    private let group: DispatchGroup = DispatchGroup()
    
    private var result: _Result = .pending {
        didSet {
            guard case .pending = oldValue else {
                preconditionFailure("A promise was completed multiple times.")
            }
            group.leave()
        }
    }
    
    private var fannedOut = false
    var callbacks: [Callback] = []
    
    init(queue: DispatchQueue = .global()) {
        self.queue = queue
        group.enter()
        group.notify(queue: queue, work: .init(block: fanout))
    }
    
    private func fanout() {
        lock.withLock {
            guard !self.fannedOut else {
                preconditionFailure("Attempt to fanout multiple times")
            }
            guard case .result(let result) = self.result else {
                preconditionFailure("Attempt to fanout before promise has completed")
            }
            self.fannedOut = true
            for callback in self.callbacks {
                self.queue.async { [result] in
                    callback(result)
                }
            }
            self.callbacks = []
        }
    }
    
    private func schedule(_ callback: @escaping Callback) {
        lock.withLock {
            if self.fannedOut {
                guard case .result(let result) = self.result else {
                    preconditionFailure("Promise fanned out but result is still pending")
                }
                self.queue.async { [callback, result] in callback(result) }
            } else {
                self.callbacks.append(callback)
            }
        }
    }
    
    func finish(with result: Result) {
        lock.withLock {
            self.result = .result(result)
        }
    }
    
    func whenSuccess(_ callback: @escaping (T) -> ()) {
        schedule {
            if case .success(let result) = $0 {
                callback(result)
            }
        }
    }
    
    func whenFailure(_ callback: @escaping (Error) -> ()) {
        schedule {
            if case .failure(let result) = $0 {
                callback(result)
            }
        }
    }
    
    func whenCompelete(_ callback: @escaping Callback) {
        schedule(callback)
    }
}

actor AsyncDispatchPromise<T> {
    actor StateActor {
//        var result: T?
//        var waiters: [(T) -> ()] = []
        var state: (result: T?, waiters: [(T) -> ()]) = (nil, [])
        
        func fulfill(result: T) -> Bool {
            if let _ = state.result {
                return false
            } else {
                state.result = result
                for waiter in state.waiters {
                    waiter(result)
                }
                state.waiters.removeAll()
                return true
            }
        }
        
        func read(_ callback: @escaping (T) -> ()) {
            if let result = state.result {
                callback(result)
            } else {
                state.waiters.append(callback)
            }
        }
    }
    
    private var _result: T?
    private var waiters: [(T) -> ()] = []
    
    private var stateActor = StateActor()
    
    private func fulfillHere(with value: T) {
        if let _ = _result {
            return
        } else {
            _result = value
            for waiter in waiters {
                waiter(value)
            }
            waiters.removeAll()
        }
    }
    
    nonisolated func fulfill(with value: T) {
        Task {
            await self.fulfillHere(with: value)
        }
    }
    
    func whenComplete(_ callback: @escaping (T) -> ()) {
        if let result = _result {
            callback(result)
        } else {
            waiters.append(callback)
        }
    }
    
    nonisolated var result: T {
        get async {
            await withCheckedContinuation { continuation in
                Task {
                    await self.whenComplete(continuation.resume(returning:))
                }
            }
        }
    }
}
