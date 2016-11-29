//
// Copyright (c) 2015 Dario Lencina and Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// ActorSystem.swift
// The ActorSystem implementation
//

import Foundation
import Dispatch



/// All actors live in 'ActorSystem'. There may be more than one actor system in
/// an application.
/// ActorSystem contains a special actorCell, the `userContext`, and an actor
/// instance with some special error handling mechanisms
public class ActorSystem : CustomStringConvertible {

    /// The name of this ActorSystem
    public let name : String

    public var description: String {
        return "ActorSystem[\(name)]"
    }

    /// The dispatcher used for the whole system
    private var dispatcher: Dispatcher

    /// The rootRef of this system
    private let userRef:ActorRef

    /// Interal semaphore to control the life cycle
    let semaphore:DispatchSemaphore

    /// Internal single queue
    let cQueue = DispatchQueue(label: "cQueue", attributes: .concurrent)

    /// Create the actor system
    /// - parameter name: The name of the actor system
    /// - parameter dispatcher: The dispatcher used for the actor system. 
    ///   Default is DefaultDispatcher
    public init(name : String, dispatcher: Dispatcher = DefaultDispatcher()) {

        self.name = name
        self.dispatcher = dispatcher

        userRef = ActorRef(path: ActorPath(path:"/user"))
        semaphore = DispatchSemaphore(value: 0)
        let userContext = ActorCell(system:self,
                                    parent:nil,
                                    actorConstructor: Actor.init,
                                    actorRef:userRef)
        userRef.actorCell = userContext
        // Later we can create an actor with special error handling mechanism
        userContext.actor = Actor(context:userContext)

    }

    /// Used for a child actor cell to get an exeuction queue
    internal func assignQueue() -> DispatchQueue {
        //return dispatcher.assignQueue()
        return cQueue;
    }


    /// Create an actor from an actor constructor with a name
    /// Parameter name: the name of the actor
    /// Parameter actorConstructor: how to create the actor, the type must be
    ///  `(ActorCell)->Actor`. It could be an actor's constructor or a closure.
    public func actorOf(name: String,
                        _ actorConstructor: @escaping (ActorCell)->Actor
                       ) -> ActorRef {
        return userRef.actorCell!.actorOf(name:name, actorConstructor)
    }


    /// ActorSystem's actorFor expects the sections with ["user", "aName"]
    /// or ["system", "aName" ], or ["deadLeater"]
    public func actorFor(_ pathSections:ArraySlice<String>) -> ActorRef? {

        if pathSections.count == 0 { return nil }
        if pathSections.first! == "user" {
            return userRef.actorFor(pathSections.dropFirst())
        } else {
            return nil
        }
    }

    /// Actorsystem's actorFor expects the path is "/user/path", or "user/path"
    public func actorFor(_ path:String) -> ActorRef? {
        var pathSecs = ArraySlice<String>(path.components(separatedBy: "/"))
        //at least one "" in the pathSecs
        if pathSecs.last! == "" { pathSecs = pathSecs.dropLast() }
        if pathSecs.count == 0 { return nil } //Empty "" input case
        if pathSecs.first! == "" { //Absolute path "/something" case
            pathSecs = pathSecs.dropFirst()
        }
        return actorFor(pathSecs)
    }

    /// TBD. Not a stable API.
    public func selectActor(pathString : String, by requestor:ActorRef,
                            _ action:@escaping (ActorRef?)->Void) {
        userRef ! Actor.ActorSelect(path:pathString, sender:requestor, action)
    }

    /// Wait the ActorSystem to be shut down, otherwise wait forever.
    /// User can call waitFor
    public func wait() {
        semaphore.wait()
    }

    /// Wait for the ActorSystem to be shut down for the input input `seconds`.
    /// If timeout, stop waiting and continue.
    /// - return DispatchTimeoutResult, which is an enumeration .success or 
    ///   .timedOut
    public func waitFor(seconds:Int) -> DispatchTimeoutResult {
        return semaphore.wait(timeout: DispatchTime.now() + .seconds(seconds))
    }

    /// Shut down the actor system. This will trigger a poison pill message sent
    /// to the root actor, and it then will send poison pills to all the actors
    /// recursively until the whole system shut down.
    /// The shut down process may last long depends the whole actor system.
    ///
    /// This can be called outside the actor system or inside the actor system.
    /// For example, in an actor's code, `context.system.shutDown()`.
    public func shutdown() {
        userRef.actorCell!.stop()
    }
    
    deinit {
        #if DEBUG
            print("ActorSystem: \(name)")
        #endif
    }
}
