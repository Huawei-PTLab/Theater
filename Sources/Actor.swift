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

/**
     '!' Is a shortcut for typing:
     
     ```
     actor ! msg
     ```
     
     instead of
     
     ```
     actorRef.tell(msg)
     ```
 */

@_transparent
public func !(actorRef : ActorRef, msg : Actor.Message) -> Void {
    actorRef.tell(msg)
}

public typealias Receive = (Actor.Message) throws -> (Void)

/**
    Actors are the central elements of Theater.

    ## Subclassing notes

    You must subclass Actor to implement your own actor classes such as: BankAccount, Device, Person etc.

    the single most important to override is
     
    ```
    public func receive(msg : Actor.Message) -> Void
    ```
     
    Which will be called when some other actor tries to ! (tell) you something
*/
open class Actor {

    public unowned let context:ActorCell

    // Short cut
    public var this: ActorRef { return context.this }

    public init(context:ActorCell) { self.context = context }
    


    /// The default function to do supervision work. 
    /// User may override this function to implement other supervision strategy
    open func supervisorStrategy(errorMsg: ErrorMessage) -> Void {
        switch(errorMsg) {
        default:
            print("\(self.this) got \(errorMsg.error) from child \(errorMsg.sender!)")
            print("[INFO] restarting \(errorMsg.sender!.path.asString)")
            errorMsg.sender!.restart()
        }
    }


    /// Used to do statemachine transaction
    final public let statesStack : Stack<(String,Receive)> = Stack()


    
    
    /**
        Actors can adopt diferent behaviours or states, you can "push" a new
        state into the statesStack by using this method.
        
        - Parameter state: the new state to push
        - Parameter name: The name of the new state, it is used in the logs
        which is very useful for debugging
    */
    final public func become(_ name : String, state : @escaping Receive) -> Void  {
        become(name, state : state, discardOld : false)
    }
    
    /**
         Actors can adopt diferent behaviours or states, you can "push" a new
         state into the statesStack by using this method.
         
         - Parameter state: the new state to push
         - Parameter name: The name of the new state, it is used in the logs
         which is very useful for debugging
     */
    final public func become(_ name : String, state : @escaping Receive, discardOld: Bool) -> Void { 
        if discardOld {
             _ = self.statesStack.replaceHead(element: (name, state))
        } else {
             self.statesStack.push(element: (name, state))
        }
    }

    /**
        Pop the state at the head of the statesStack and go to the previous
        stored state
    */
    final public func unbecome() { let _ = self.statesStack.pop() }
    
    /**
        Current state

        - Returns: The state at the top of the statesStack
    */
    final public func currentState() -> (String,Receive)? {
        return self.statesStack.head()
    }
    
    /**
        Pop states from the statesStack until it finds name

        - Parameter name: the state that you can to pop to.
    */
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
    
    /**
        pop to root state
    */
    public func popToRoot() -> Void {
        while !self.statesStack.isEmpty() {
            unbecome()
        }
    }
    

    /**
        This method will be called when there's an incoming message, notice
        that if you push a state int the statesStack this method will not be
        called anymore until you pop all the states from the statesStack.
    
        - Parameter msg: the incoming message
    */
    open func receive(_ msg : Actor.Message) throws -> Void {
        switch msg {
            default :
            #if DEBUG
                print("message not handled \(type(of:msg))")
            #endif
        }
    }


    
    /**
        preStart() is called when an Actor is ready to start. Actors are automatically started
        asynchronously when created. Different to init(), at the time this function is called, 
        the actor has all properties set, like its actor reference. 
        Empty default implementation. User can override it to create sub actors here.
    */
    open func preStart() -> Void {   }
    
    /**
        willStop() is called when an Actor receive stop message and before any destruction 
        operations. User can override this function to do cleanup.
     */
    open func willStop() -> Void {   }
    


    /*
        Schedule Once is a timer that executes the code in block after seconds
        and can cancle
    */
    public typealias Task = (Bool) -> Void 

    //TODO
    // public func delay(time:TimeInterval, task: ()->() ) ->  Task? {     
        
        // func dispatch_later(block:()-> ()) {
            // underlyingQueue.after(when: DispatchTime.now() + time,
                                       // execute: block)
        // }

        // let delayedClosure: Task = {
            // cancel in
            // if let internalClosure = closure {
                // if (cancel == false) {                
                    // self.underlyingQueue.after(when: DispatchTime.now() + time,
                                               // execute: internalClosure)
                // }
            // }
            // closure = nil
            // result = nil
        // }

        // result = delayedClosure

        // dispatch_later {
            // if let delayedClosure = result {            
                // delayedClosure(cancel: false)
            // }
        // }

        // return result
    // }

    //TODO
    // public func cancel(task:Task?, cancle:Bool) {
    //     task?(cancel: cancle)
    // }


    deinit {
        #if DEBUG
            print("[INFO] deinit \(self.this.path.asString)")
        #endif
    }

}
