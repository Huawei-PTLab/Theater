//
// Copyright (c) 2015 Dario Lencina and Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// ActorSystem.swift
// The ActorSystem implementation
//

import Foundation
import Dispatch


/**
    All actors live in 'ActorSystem'. You might have more than 1 actor system.
    ActorSystem is a special actorcell, with some special error handling mechanism
*/
public class ActorSystem : CustomStringConvertible {

    /// The name of this ActorSystem
    public let name : String

    public var description: String {
        return "ActorSystem[\(name)]"
    }

    /// The dispatcher used for the whole system
    private var dispatcher: Dispatcher = DefaultDispatcher()

    /// The rootRef of this system
    private let rootRef:ActorRef


    /// Create the actor system
    /// - parameter name: The name of the actor system
    /// - parameter dispatcher: The dispatcher used for the actor system. Default is DefaultDispatcher
    public init(name : String, dispatcher: Dispatcher = DefaultDispatcher()) {


        self.name = name
        self.dispatcher = dispatcher

        rootRef = ActorRef(path: ActorPath(path:"/user"))
        let rootContext = ActorCell(system:self,
                                    parent:nil,
                                    actorConstructor: Actor.init,
                                    actorRef:rootRef)
        rootRef.actorCell = rootContext
        rootContext.actor = Actor(context:rootContext)


    }

    internal func assignQueue() -> DispatchQueue {
        return dispatcher.assignQueue()
    }


    public func actorOf(_ actorConstructor: @escaping (ActorCell)->Actor,
                        name: String) -> ActorRef {
        return rootRef.actorCell!.actorOf(actorConstructor, name:name)
    }


    public func actorFor(_ pathSections:ArraySlice<String>) -> ActorRef? {
        return rootRef.actorFor(pathSections)
    }

    public func actorFor(_ path:String) -> ActorRef? {
        return rootRef.actorFor(path)
    }

    public func selectActor(pathString : String, by requestor:ActorRef,
                            _ action:@escaping (ActorRef?)->Void) {
        rootRef ! Actor.ActorSelect(path:pathString, sender:requestor, action)
    }

    public func stop() {
        rootRef.actorCell!.stop()
    }
    
    deinit {
        #if DEBUG
            print("killing ActorSystem: \(name)")
        #endif
    }
}
