//
// Copyright (c) 2015 Dario Lencina and Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// ActorSystem.swift
// The ActorSystem implementation
//

import Foundation
import Dispatch



/// All actors live in 'ActorSystem'. You might have more than 1 actor system.
/// ActorSystem contains a special actorCell and an actor instance with some
/// special error handling mechanisms
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


    /// Create the actor system
    /// - parameter name: The name of the actor system
    /// - parameter dispatcher: The dispatcher used for the actor system. 
    ///   Default is DefaultDispatcher
    public init(name : String, dispatcher: Dispatcher = DefaultDispatcher()) {

        self.name = name
        self.dispatcher = dispatcher

        userRef = ActorRef(path: ActorPath(path:"/user"))
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
        return dispatcher.assignQueue()
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

    public func stop() {
        userRef.actorCell!.stop()
    }
    
    deinit {
        #if DEBUG
            print("ActorSystem: \(name)")
        #endif
    }
}
