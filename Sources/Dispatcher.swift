//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// Dispatcher.swift
// The Dispatcher implementation.
//

import Dispatch 
import Foundation
import SwiftDataStructure 

public enum DispatcherType {
    case Sequential ///Pure sequential, using a single global queue
    case Individual ///Each Actor has its own GCD sequential queue
    case Share      ///All shared actor use one GCD sequential queue
    case Concurrent ///All actors use one GCD concurrent queue
    case System     ///Inherit the Dispatcher defined in ActorSystem
}

public typealias SystemReceive = (Actor.Message) -> (Void)

/// The mailbox Base protocol
/// It only has one requirement that ActorCell can deliver msg into it.
protocol Dispatcher {
    func put(_ msg : Actor.Message)
}

/// Only used when the initialization of the ActorCell.
struct EmptyDispatcher : Dispatcher {
    func put(_ msg : Actor.Message) {
        ///TBD
    }
}

class SequentialExecutor {
    var running : Bool = false // by default is false
    typealias Task = ()->()
    var taskQueue = FastQueue<Task>(initSize:100)

    func putAndRun(task: @escaping Task) {
        taskQueue.enqueue(item:  task)
        if !running {
            running = true
            while let task = taskQueue.dequeue() {
                task() //run the task, during the step, more tasks may be added
            }
            running = false
        }
    }
}

/// Without a lock, pure sequential execution. The algorithm is similar to the
/// concurrent dispatcher
class SequentialDispatcher : Dispatcher {
    static let executor = SequentialExecutor()

    let mailbox = FastQueue<Actor.Message>(initSize:8)
    let task:(Actor.Message)->Void
    var notRunning = true

    init(task:@escaping SystemReceive) {
        self.task = task
    }

    func put(_ msg : Actor.Message) {
        mailbox.enqueue(item:msg)
        if (notRunning) {
            notRunning = false
            SequentialDispatcher.executor.putAndRun(task:runTask)
        }
    }

    func runTask() {
        while let msg = mailbox.dequeue() {
            self.task(msg)
        }
        notRunning = true
    }
}


struct IndividualDispatcher : Dispatcher {
    let task:(Actor.Message)->Void
    let dispatchQueue:DispatchQueue

    init(task:@escaping SystemReceive) {
        self.task = task
        dispatchQueue = DispatchQueue(label: "")
    }

    func put(_ msg : Actor.Message) {
        dispatchQueue.async {
            self.task(msg)
        }
    }
}

struct ShareDispatcher : Dispatcher {
    let task:(Actor.Message)->Void
    let dispatchQueue:DispatchQueue

    init(task:@escaping SystemReceive, queue:DispatchQueue) {
        self.task = task
        dispatchQueue = queue
    }

    func put(_ msg : Actor.Message) {
        dispatchQueue.async {
            self.task(msg)
        }
    }
}


/// Sytle one directly use the queue as
/// Must use as a class. Struct, pass it into a closure
class ConcurrentDispatcher : Dispatcher {
    let task:(Actor.Message)->Void
    let dispatchQueue:DispatchQueue

    let lock: DispatchSemaphore
    let mailbox = FastQueue<Actor.Message>(initSize:8)
    var notRunning = true


    init(task:@escaping SystemReceive,
         queue:DispatchQueue,
         lock: DispatchSemaphore) {
        self.task = task
        dispatchQueue = queue
        self.lock = lock
    }

    func put(_ msg : Actor.Message) {
        lock.wait()
        mailbox.enqueue(item:msg)
        if (notRunning) {
            notRunning = false
            dispatchQueue.async { [unowned self] in
                self.runTask()
            }
        }
        lock.signal()
    }

    func runTask() {
        lock.wait()
        while let msg = mailbox.dequeue() {
            //now still in running
            lock.signal()
            self.task(msg)
            lock.wait()
        }
        notRunning = true
        lock.signal()
    }

}
