//
// Copyright (c) 2016 Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// ActorRef.swift
// The ActorRef implementation
//

import Foundation

/// An actor system has a tree like structure, ActorPath gives you an url like
/// way to find an actor inside a given actor system.
///
/// For now ActorPath only stores a String path. In the future this class can
/// be extended to store network path, communication protocol, etc.

/// ActorPath is used to mark the location of an ActorRef.
/// The simple ActorRef points to a local ActorCell, and the ActorPath is just 
//  simple path String, like "\user\ping", "\user\pong"
/// ActorPath can be extended later to store network path, communication 
/// protocol, etc.
public class ActorPath : CustomStringConvertible {
    
    public let asString : String

    public var description: String { 
        return asString
    }
    
    public init(path : String) {
        self.asString = path
    }
}

extension ActorPath: Hashable {
    public var hashValue: Int {
        return asString.hashValue
    }
}

public func ==(lhs: ActorPath, rhs: ActorPath) -> Bool {
    return lhs.asString == rhs.asString
}

/// ActorRef is a reference to an Actor (ActorCell)
/// Programmer typically will always talk to the actor throught this ref
public class ActorRef: CustomStringConvertible {

    public var description: String {
        return "<\(type(of:self)): \(path)>"
    }

    /// Actor path could be:/user/aName, /deadLeater, /system/system1
    /// The shortName is always the last section
    public var shortName: String {

        let shortName = path.asString.components(separatedBy: "/").last
        guard shortName != nil else {
            preconditionFailure("[ERROR] Wrong actorPath:\(description)")
        }
        return shortName!
    }

    /// ActorRef owns an ActorCell. So this is a strong optional type. And 
    /// after the actorcell is stopped. The actor will be cleaned
    public var actorCell: ActorCell?

    /// ActorPath of this ActorRef
    public let path : ActorPath
    
    /// Called by ActorCell.actorOf
    init(path : ActorPath) {
        self.path = path
    }

    /// Look for an actor in the current actor context
    /// The input is an array of strings. For example, if there is an actor
    /// "/user/Parent/Son". And if the actorFor() is called in "/user/Parent"
    /// actor, and input is "[Son]", the "/user/Parent/Son" will be returned.
    /// - Parameter pathSections: ArraySlice of String to express each section.
    /// - Returns: The actor ref corresponding to the path or nil if not found
    public func actorFor(_ pathSections:ArraySlice<String>) -> ActorRef? {
        return actorCell?.actorFor(pathSections)
    }

    /// Look for an actor in the current actor context
    /// The input is an absolute path, staring with "/", or relative path,
    /// starting with "." or ".." or a name. 
    /// For example, if there is an actor "/user/Parent/Son". And if the 
    /// actorFor() is called in "/user/Parent" actor with input is "Son", or 
    /// "./Son", or "../Parent/Son", or "/user/Parent/Son", the
    /// "/user/Parent/Son" will be returned.
    /// - Parameter path: Relative path in String
    /// - Returns: The actor ref corresponding to the path or nil if not found
    public func actorFor(_ path:String) -> ActorRef? {
        return actorCell?.actorFor(path)
    }


    /// This method is used to send a message to the underlying Actor.
    /// - parameter msg : The message to send to the Actor.
    public func tell (_ msg : Actor.Message) -> Void {
        if let actorCell = self.actorCell {
            ///Here we should just put the msg into actorCell's queue
            actorCell.tell(msg)
        } else {
            print("[WARNING] Fail to deliver message \(msg) from \(msg.sender) to \(self)")
        }
    }

    internal func stop(_ ref: ActorRef) {
        if let actorCell = self.actorCell {
            actorCell.stop() // the system message
        } else {
            // TODO:
            //send error msg to system. log
        }
    }
}

extension ActorRef : Hashable {
    public var hashValue: Int {
        return path.hashValue
    }
}

public func ==(lhs: ActorRef, rhs: ActorRef) -> Bool {
    return lhs.path == rhs.path
}
