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
/// ActorSystem contains a special actorCell and an actor instrance with some
/// special error handling mechanism
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

    /// Used for child actor cell to get an exeuction queue
    internal func assignQueue() -> DispatchQueue {
        return dispatcher.assignQueue()
    }


    public func actorOf(_ actorConstructor: @escaping (ActorCell)->Actor,
                        name: String) -> ActorRef {
        return userRef.actorCell!.actorOf(actorConstructor, name:name)
    }


    /// ActorSystem's actorFor expects the sections with ["user", "aName"]
    /// or ["system", "aName" ], or ["deadLeater"]
    public func actorFor(_ pathSections:ArraySlice<String>) -> ActorRef? {

        if pathSections.count == 0 { return nil }
        if pathSections.first! == "user" {
            print("now check user")
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
