//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// Dispatcher.swift
// The Dispatcher implementation.
//


import Dispatch 
import Foundation

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
    let systemQueue = DispatchQueue(label: "system")
    var queues = [DispatchQueue]()
    var randomQueue: DispatchQueue? = nil
    let maxQueues = 10000
    var queueCount = 0

    public init() {
        srandom(UInt32(NSDate().timeIntervalSince1970))
    }

    public func assignQueue() -> DispatchQueue {
        if queueCount < maxQueues {
            let newQueue = DispatchQueue(label: "")
            if randomQueue == nil { randomQueue = newQueue }
            queueCount += 1
            systemQueue.async { () in 
                self.queues.append(newQueue)
                let randomNumber = Int(rand())
                if randomNumber % 2 == 0 {
                    self.randomQueue = newQueue
                }
            }
            return newQueue
        } else {
            systemQueue.async { () in 
                let randomNumber = Int(rand()) % self.maxQueues
                self.randomQueue = self.queues[randomNumber]
            }
            return randomQueue!
        }
    }

    public func assignQueue(name: String) -> DispatchQueue {
        return DispatchQueue(label: name)
    }
}
