//
// Copyright (c) 2015 Dario Lencina and Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// Actor.swift
// The basic Actor definition
//

import Foundation
import Dispatch

precedencegroup ActorMessageSendGroup {
    associativity: left
    higherThan: AssignmentPrecedence
    lowerThan: TernaryPrecedence
}
infix operator ! : ActorMessageSendGroup
//infix operator ! {associativity left precedence 130}

/// '!' is used to send message to an actor.
/// It is a shortcut for typing:
///  `actor ! msg` instead of `actorRef.tell(msg)`
@_transparent
public func !(actorRef : ActorRef, msg : Actor.Message) -> Void {
    actorRef.tell(msg)
}


/// A function type to receive a message
/// In the actor FSM model, each state's handler message should have this type.
public typealias Receive = (Actor.Message) throws -> (Void)

/// Actor is the basic element in the actor system. Actors can only interact
/// through message sending. 
/// The way to implement a real actor is to subclass the Actor class, and 
/// override the function `func receive(msg : Actor.Message) -> Void`.
/// This message will be called when some other actor tries to deliver a message
/// to this actor through `!` operator or `tell()` method.
open class Actor {

    /// The contact of this actor
    public unowned let context:ActorCell

    /// Short cut to access the ActorRef of this actor.
    public var this: ActorRef { return context.this }

    /// The base constructor of an actor. The context field must be passed in.
    public init(context:ActorCell) { self.context = context }

    /// The default function to do supervision work. 
    /// When the supervisor actor receives an error message, it will report
    /// the error message and try to restart the actor who has the error.
    /// User may override this function to implement other supervision strategy
    open func supervisorStrategy(errorMsg: ErrorMessage) -> Void {
        switch(errorMsg) {
        default:
            print("[WARNING]\(self.this) got \(errorMsg.error) from child \(errorMsg.sender!)")
            print("[WARNING]  restarting \(errorMsg.sender!.path.asString)")
            errorMsg.sender!.restart()
        }
    }

    /// Used to do statemachine transaction in actor's FSM mode
    final public let statesStack : Stack<(String,Receive)> = Stack()

    /// Actors can adopt diferent behaviours or states, you can "push" a new
    /// state into the statesStack by using this method.
    /// - Parameter state: the new state to push
    /// - Parameter name: The name of the new state, it is used in the logs
    ///   which is very useful for debugging
    final public func become(_ name: String, state: @escaping Receive) -> Void {
        become(name, state : state, discardOld : false)
    }
    

    /// Actors can adopt diferent behaviours or states, you can "push" a new
    /// state into the statesStack by using this method.
    /// - Parameter state: the new state to push
    /// - Parameter name: The name of the new state, it is used in the logs
    ///   which is very useful for debugging
    /// - Parameter discardOld: whether to replace the previous state or keep 
    ///   the previous state
    final public func become(_ name : String, state : @escaping Receive, discardOld: Bool) -> Void {
        if discardOld {
             _ = self.statesStack.replaceHead(element: (name, state))
        } else {
             self.statesStack.push(element: (name, state))
        }
    }

    /// Pop the state at the head of the statesStack and go to the previous
    /// stored state
    final public func unbecome() { let _ = self.statesStack.pop() }

    /// Return the current state in the state machine
    /// - Returns: The state at the top of the statesStack
    final public func currentState() -> (String,Receive)? {
        return self.statesStack.head()
    }
    

    /// Pop states from the statesStack until it finds name
    /// - Parameter name: the state that you can to pop to.
    open func popToState(name : String) -> Void {
        if let (hName, _ ) = self.statesStack.head() {
            if hName != name {
                unbecome()
                popToState(name: name)
            }
        } else {
            #if DEBUG
                print("unable to find state with name \(name)")
            #endif
        }
    }
    
    /// Clean all the states in the stack of the current state machine
    public func popToRoot() -> Void {
        while !self.statesStack.isEmpty() {
            unbecome()
        }
    }

    /// This method will be called when there's an incoming message, notice
    /// that if you push a state int the statesStack this method will not be
    /// called anymore until you pop all the states from the statesStack.
    /// - Parameter msg: the incoming message
    open func receive(_ msg : Actor.Message) throws -> Void {
        switch msg {
            default :
            #if DEBUG
                print("message not handled \(type(of:msg))")
            #endif
        }
    }


    /// preStart() is called when an Actor is ready to start and befoe it
    /// receives the first message.
    /// Actors are automatically started asynchronously when created. Different 
    /// to init(), at the time this function is called, the actor has all 
    /// properties set, like its actor reference, actor context.
    open func preStart() -> Void {   }

    /// willStop() is called when an Actor receives stop message and before any 
    /// destruction operations. User can override this function to do cleanup.
    open func willStop() -> Void {   }
    
    /// postStop() is called after an actor has stopped. This indicates that all
    /// of its children have stopped and it is ready to be cleaned up.
    open func postStop() -> Void {   }
    
    /// childTerminated(:) is called when an actor's child reports that it was 
    /// terminated, allowing the actor to take any necessary actions.
    open func childTerminated(_ child: ActorRef) {   }

    deinit {
        #if DEBUG
            print("[INFO] deinit \(self.this.path.asString)")
        #endif
    }

}
