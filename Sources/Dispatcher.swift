//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// Dispatcher.swift
// The Dispatcher implementation.
//

import Dispatch 
import Foundation
#if os(OSX) || os(iOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif



func randomInt()->Int {
    #if os(Linux)
    return random()
    #else
    return Int(arc4random())
    #endif
}

public protocol Dispatcher {
    func assignQueue() -> DispatchQueue
    func assignQueue(name: String) -> DispatchQueue
}

/**
    Assign a new dispatch_queue every time
*/
public class DefaultDispatcher: Dispatcher {
    public func assignQueue() -> DispatchQueue {
        return DispatchQueue(label: "")
    }    

    public func assignQueue(name: String) -> DispatchQueue {
        return DispatchQueue(label: name)
    }
}

/**
    Share queues between actors
*/
public class ShareDispatcher: Dispatcher {
    /** 
        Ensure thead-safe access to type properties
    */
    let lock = NSLock()
    var queues = [DispatchQueue]()
    var randomQueue: DispatchQueue? = nil
    let maxQueues: Int
    var queueCount = 0

    public init(queues:Int) {
        maxQueues = queues
        srandom(UInt32(NSDate().timeIntervalSince1970))
    }

    public func assignQueue() -> DispatchQueue {
        lock.lock()
        defer { lock.unlock() }
        if queueCount < maxQueues {
            let newQueue = DispatchQueue(label: "")
            if randomQueue == nil { randomQueue = newQueue }
            queueCount += 1
            self.queues.append(newQueue)
            return newQueue
        } else {
            let randomNumber = randomInt() % self.maxQueues
            return self.queues[randomNumber]
        }
    }

    public func assignQueue(name: String) -> DispatchQueue {
        return DispatchQueue(label: name)
    }
}
