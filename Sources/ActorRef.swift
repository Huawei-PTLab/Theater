//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// ActorRef.swift
// The ActorRef implementation
//

import Foundation

/**
tomStringConverAn actor system has a tree like structure, ActorPath gives you an url like
    way to find an actor inside a given actor system.

    For now ActorPath only stores a String path. In the future this class can
    be extended to store network path, communication protocol, etc. 
*/

/// ActorPath is used to locate mark the location of an ActorRef
/// The simple ActorRef points to a local ActorCell, and the ActorPath is just a simple url String
/// ActorPath can be extended later to store network path, communication protocol, etc.
public class ActorPath : CustomStringConvertible {
    
    public let asString : String

    public var description: String { 
        return asString
    }
    
    public init(path : String) {
        self.asString = path
    }
}

/// ActorRef is a reference to an Actor (ActorCell)
/// Programmer typically will always talk to the actor throught this ref
public class ActorRef: CustomStringConvertible {
    
    /**
        For debugging
    */
    public var description: String {
        return "<\(type(of:self)): \(path)>"
    }

    /// ActorRef owns an ActorCell. So this is a strong optional type. And after the actorcell is stopped.
    /// The actor will be cleaned
    var actorCell: ActorCell?

    /// ActorPath of this ActorRef
    public let path : ActorPath


    
    /// Called by ActorCell.actorOf
    init(path : ActorPath) {
        self.path = path
    }

    public func actorFor(_ pathSections:ArraySlice<String>) -> ActorRef? {
        return actorCell?.actorFor(pathSections)
    }

    public func actorFor(_ path:String) -> ActorRef? {
        return actorCell?.actorFor(path)
    }

    /**
        This method is used to send a message to the underlying Actor.
     
        - parameter msg : The message to send to the Actor.
    */
    public func tell (_ msg : Actor.Message) -> Void {
        if let actorCell = self.actorCell {
            ///Here we should just put the msg into actorCell's queue
            actorCell.tell(msg)
        } else {
            print("[WARNING] Fail to deliver message \(msg) to \(self)")
        }
    }


    internal func stop(_ ref: ActorRef) {
        if let actorCell = self.actorCell {
            actorCell.stop() // the system message
        } else {
            //send error msg to system. log
        }

    }
}
